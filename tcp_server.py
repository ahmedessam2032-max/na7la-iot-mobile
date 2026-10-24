import asyncio
import json
import re
import socket
import uuid
from datetime import datetime, timezone
from typing import Callable, Coroutine, Any, Optional

from config import settings
from crypto_utils import mask_mac, mask_ip
from database import SessionLocal
from models import Strip, Socket, AuditLog, EnergyLog, OutletRunSession, find_strip_by_mac
from plugins import PROTECTION_AND_AUTOMATION_RULES, log_event

# التعبيرات النمطية لبروتوكول المشترك (Stock 0.1.54-1.0.66)
BOOTINFO_RE = re.compile(
    r"^up:bootinfo:([^;\r\n]+);([0-9A-Fa-f]{12});([0-9A-Fa-f]{12});([^;\r\n]+);connect$"
)
GETINFO_RE = re.compile(
    r"(?P<ch>[1-5]):(?P<runtime>-?\d+);(?P<relay>on|off);(?P<state>-?\d+);"
    r"(?P<overload>[^;:]+);(?P<overheat>[^;:]+);(?P<power>-?\d+);"
    r"(?P<energy>[0-9A-Fa-f]{8});(?P<previous>[0-9A-Fa-f]{8});"
    r"(?P<config>[0-9A-Fa-f]{8});(?P<status>[^;:]+);"
    r"(?P<event>[0-9A-Fa-f]{2});(?P<temperature>-?\d+)",
    re.I,
)
ONOFF_ACK_RE = re.compile(r"^up:onoff:([1-4]):(on|off)$", re.I)
EVENT_RE = re.compile(r"^up:event:onoff:([0-4]):(on|off)$", re.I)
POWER_REPORT_RE = re.compile(r"^up:power_report:([1-5]):(-?\d+)$", re.I)
QUERY_RE = re.compile(r"^up:query:(-?\d+)$")
CHILDLOCK_ACK_RE = re.compile(r"^up:(?:childlock|cl):(?:ok|state|set):(?:mask:)?(\d{1,2})$", re.I)
CHILDLOCK_STATE_RE = re.compile(r"^up:(?:childlock|cl):(?:mask:)?(\d{1,2})$", re.I)


def parse_childlock_line(line: str) -> Optional[int]:
    """فك تشفير ردود قفل الأطفال (up:childlock / up:cl) واستخراج قناع الخانات (0..31)"""
    clean = line.strip("\r\n\x00 ")
    if not re.match(r"^up:(?:childlock|cl)(?::.*)?$", clean, re.I):
        return None
    m = re.search(r"(?:^|:)(?:mask:)?(3[01]|[12]?\d)(?:$|:)", clean, re.I)
    if m:
        return int(m.group(1))
    return None


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def calibrate_current(raw_amps: float, power_w: float = 0.0) -> float:
    """معايرة تيار المخرج بأسلوب العتبة الذكية (Deadband Threshold) لمنع تشويه قراءات الأحمال الصغيرة"""
    if raw_amps <= 0.0 or power_w < 0.3:
        return 0.0
    if power_w >= 0.8:
        return round(raw_amps, 3)
    return round(max(0.0, raw_amps - settings.CURRENT_NOISE_OFFSET_AMP), 3)


def parse_getinfo(line: str) -> list[dict]:
    """فك تشفير تقرير الحالة والحساسات (up:getinfo) مع إلغاء الفلاج المضلل"""
    text = line.strip("\r\n\x00 ")
    if text.startswith("up:getinfo:"):
        text = text[len("up:getinfo:"):]
    out = []
    for m in GETINFO_RE.finditer(text):
        g = m.groupdict()
        ch = int(g["ch"])
        if ch > 4:
            continue
        out.append({
            "n": ch,
            "on": g["relay"].lower() == "on",
            "runtime_sec": max(0, int(g["runtime"])),
            "overload": False,
            "overheat": False,
            "power_w": round(max(0, int(g["power"])) / 1000.0, 2),
            "energy_kwh": round(int(g["energy"], 16) / 1000.0, 3),
            "temp_c": int(g["temperature"]),
        })
    return out


class StripSession:
    """جلسة اتصال TCP آمنة لمشترك واحد مع قفل التزامن (Mutex Lock)"""

    def __init__(self, ip: str, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        self.session_uuid = str(uuid.uuid4())
        self.ip = ip
        self.reader = reader
        self.writer = writer
        self.lock = asyncio.Lock()
        self.got_getinfo = asyncio.Event()
        self.got_childlock = asyncio.Event()
        self.last_childlock_mask: Optional[int] = None

        self.mac: Optional[str] = None
        self.strip_id: Optional[int] = None
        self.model: str = "lgutap"
        self.fw_version: str = "0.1.55"
        self.last_cmd = ""
        self.last_rx = ""

        # عدادات الحماية والتأكيد المزدوج
        self.consecutive_voltage_faults = 0
        self.voltage_recovery_streak = 0
        self.voltage_recovery_started_at: Optional[datetime] = None
        self.voltage_tripped = False

        sock = writer.get_extra_info("socket")
        if sock is not None:
            try:
                sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            except OSError:
                pass

    async def send_raw(self, cmd: str) -> None:
        if self.writer.is_closing():
            return
        self.last_cmd = cmd
        try:
            self.writer.write((cmd + "\r\n").encode("ascii"))
            await self.writer.drain()
        except Exception:
            pass

    async def _refresh_unlocked(self, timeout: float = 3.5) -> bool:
        self.got_getinfo.clear()
        await self.send_raw("up:getinfo:all")
        try:
            await asyncio.wait_for(self.got_getinfo.wait(), timeout)
            return True
        except asyncio.TimeoutError:
            return False

    async def refresh(self, timeout: float = 3.5) -> bool:
        async with self.lock:
            return await self._refresh_unlocked(timeout)

    async def set_outlets(self, channels: list[int], on: bool, stagger_sec: float = settings.STAGGER_DEFAULT_SEC) -> bool:
        """تشغيل أو إطفاء المقابس بتتابع زمني لمنع شرارة البدء وتيار الإقلاع"""
        async with self.lock:
            for idx, ch in enumerate(channels):
                await self.send_raw(f"up:onoff:{ch}:{'on' if on else 'off'}")
                if idx < len(channels) - 1 and stagger_sec > 0:
                    await asyncio.sleep(stagger_sec)
            await asyncio.sleep(settings.RELAY_SETTLE_DELAY_SEC)
            return await self._refresh_unlocked()

    async def query_diagnostics(self) -> None:
        """طلب قراءة الفولت وإشارة الواي فاي"""
        async with self.lock:
            await self.send_raw("up:power_report:1:vol")
            await asyncio.sleep(0.1)
            await self.send_raw("up:query:wifirssi")

    async def set_child_lock(self, enabled: bool, timeout: float = 2.5) -> bool:
        """تفعيل أو تعطيل قفل الأطفال على مستوى عتاد المشترك (Hardware MCU Lock)"""
        mask = 31 if enabled else 0
        async with self.lock:
            self.got_childlock.clear()
            await self.send_raw(f"up:childlock:{mask}")
            try:
                await asyncio.wait_for(self.got_childlock.wait(), timeout)
                return self.last_childlock_mask == mask
            except asyncio.TimeoutError:
                self.got_childlock.clear()
                await self.send_raw("up:childlock")
                try:
                    await asyncio.wait_for(self.got_childlock.wait(), timeout)
                    return self.last_childlock_mask == mask
                except asyncio.TimeoutError:
                    return False

    async def query_child_lock(self, timeout: float = 2.5) -> Optional[int]:
        """الاستعلام عن حالة قفل الأطفال من عتاد المشترك"""
        async with self.lock:
            self.got_childlock.clear()
            await self.send_raw("up:childlock")
            try:
                await asyncio.wait_for(self.got_childlock.wait(), timeout)
                return self.last_childlock_mask
            except asyncio.TimeoutError:
                return None


class Na7laTCPHub:
    """النواة المركزية لمنصة Na7la IoT لإدارة المشتركات وربطها بالشبكة"""

    def __init__(self) -> None:
        self.sessions: dict[str, StripSession] = {}
        self.ws_broadcaster: Optional[Callable[[str, dict], Coroutine[Any, Any, None]]] = None
        self.hourly_energy_cache: dict[int, dict[str, float]] = {}

    def get_session(self, mac: str) -> Optional[StripSession]:
        s = self.sessions.get(mac.upper())
        if s and not s.writer.is_closing():
            return s
        return None

    async def broadcast_update(self, mac: str, payload: dict) -> None:
        if self.ws_broadcaster:
            try:
                await self.ws_broadcaster(mac.upper(), payload)
            except Exception:
                pass

    async def trigger_doorbell_auto_off(self, mac: str, socket_index: int, pulse_sec: int = 3) -> None:
        """إطفاء المخرج تلقائياً بعد نبضة وضع الجرس (Doorbell Mode)"""
        await asyncio.sleep(max(1, min(60, pulse_sec)))
        session = self.get_session(mac)
        db = SessionLocal()
        try:
            strip = find_strip_by_mac(db, mac)
            if not strip:
                return
            sock = next((s for s in strip.sockets if s.socket_index == socket_index), None)
            if not sock or not getattr(sock, "doorbell_mode", False):
                return
            if session:
                await session.set_outlets([socket_index], False)
            sock.desired_state = False
            sock.reported_state = False
            sock.current_watt = 0.0
            sock.current_amp = 0.0
            sock.last_off_timestamp = utc_now()
            open_sess = db.query(OutletRunSession).filter(
                OutletRunSession.socket_id == sock.id,
                OutletRunSession.is_open == True
            ).first()
            if open_sess:
                open_sess.ended_at = utc_now()
                started = open_sess.started_at.replace(tzinfo=timezone.utc) if open_sess.started_at and open_sess.started_at.tzinfo is None else (open_sess.started_at or utc_now())
                open_sess.duration_sec = max(1, int((utc_now() - started).total_seconds()))
                open_sess.is_open = False
            log_event(db, strip.id, socket_index, "OFF", "DOORBELL_PULSE", f"إطفاء تلقائي بعد انتهاء نبضة الجرس ({pulse_sec}s)")
            db.commit()
        except Exception as err:
            print(f"[{settings.PROJECT_NAME} TCP] Doorbell auto-off error: {err}")
        finally:
            db.close()

    async def process_telemetry(self, session: StripSession, records: list[dict]) -> None:
        """معالجة قراءات الواط والأمبير والحرارة وتحديث سجل الجلسات وفحص قواعد الحماية الذكية"""
        if not session.mac:
            return
        db = SessionLocal()
        try:
            strip = find_strip_by_mac(db, session.mac)
            if not strip:
                return

            sockets_map = {s.socket_index: s for s in strip.sockets}
            total_watt = 0.0
            total_amp = 0.0
            voltage = strip.current_voltage or 220.0
            rate = strip.owner.electricity_rate_egp if (strip.owner and strip.owner.electricity_rate_egp) else 1.45

            for r in records:
                sock = sockets_map.get(r["n"])
                if not sock:
                    continue

                if sock.reported_state and not r["on"]:
                    sock.last_off_timestamp = utc_now()

                sock.reported_state = r["on"]
                sock.desired_state = r["on"]
                sock.current_watt = r["power_w"]
                sock.current_temp_c = r["temp_c"]
                sock.runtime_seconds = r["runtime_sec"]
                sock.hw_overload_flag = False
                sock.hw_overheat_flag = False

                raw_amp = (r["power_w"] / voltage) if (voltage > 0 and r["on"]) else 0.0
                sock.current_amp = calibrate_current(raw_amp, r["power_w"])

                # تصفير الآمان في حالة إعادة تعيين الفيرموير للعداد
                if r["energy_kwh"] < sock.raw_energy_kwh:
                    sock.energy_baseline_kwh = 0.0
                sock.raw_energy_kwh = r["energy_kwh"]

                total_watt += sock.current_watt
                total_amp += sock.current_amp

                # تتبع جلسات التشغيل الفردية (Run log — last 30 days)
                open_sess = db.query(OutletRunSession).filter(
                    OutletRunSession.socket_id == sock.id,
                    OutletRunSession.is_open == True
                ).first()

                if r["on"]:
                    if not open_sess:
                        open_sess = OutletRunSession(
                            strip_id=strip.id,
                            socket_id=sock.id,
                            socket_index=sock.socket_index,
                            socket_name=sock.name,
                            started_at=utc_now(),
                            start_kwh=r["energy_kwh"],
                            end_kwh=r["energy_kwh"],
                            kwh_used=0.0,
                            watt_sum=sock.current_watt,
                            sample_count=1,
                            avg_watt=sock.current_watt,
                            peak_watt=sock.current_watt,
                            cost_egp=0.0,
                            is_open=True,
                        )
                        db.add(open_sess)
                    else:
                        open_sess.socket_name = sock.name
                        open_sess.watt_sum = (open_sess.watt_sum or 0.0) + sock.current_watt
                        open_sess.sample_count = (open_sess.sample_count or 0) + 1
                        open_sess.avg_watt = round(open_sess.watt_sum / max(1, open_sess.sample_count), 1)
                        open_sess.peak_watt = round(max(open_sess.peak_watt or 0.0, sock.current_watt), 1)
                        open_sess.end_kwh = r["energy_kwh"]
                        started = (
                            open_sess.started_at.replace(tzinfo=timezone.utc)
                            if open_sess.started_at and open_sess.started_at.tzinfo is None
                            else (open_sess.started_at or utc_now())
                        )
                        dur = max(1, int((utc_now() - started).total_seconds()))
                        open_sess.duration_sec = dur
                        kwh_diff = max(0.0, r["energy_kwh"] - (open_sess.start_kwh or 0.0))
                        est_kwh = (open_sess.avg_watt * (dur / 3600.0)) / 1000.0
                        open_sess.kwh_used = round(max(kwh_diff, est_kwh), 4)
                        open_sess.cost_egp = round(open_sess.kwh_used * rate, 2)
                else:
                    if open_sess:
                        open_sess.ended_at = utc_now()
                        started = (
                            open_sess.started_at.replace(tzinfo=timezone.utc)
                            if open_sess.started_at and open_sess.started_at.tzinfo is None
                            else (open_sess.started_at or utc_now())
                        )
                        open_sess.duration_sec = max(1, int((utc_now() - started).total_seconds()))
                        open_sess.is_open = False

                # تحديث كاش الاستهلاك التراكمي
                cache = self.hourly_energy_cache.setdefault(
                    sock.id, {
                        "watt_sum": 0.0, "count": 0, "watt_max": 0.0,
                        "start_kwh": r["energy_kwh"], "last_kwh": r["energy_kwh"]
                    }
                )
                cache["watt_sum"] += sock.current_watt
                cache["count"] += 1
                cache["watt_max"] = max(cache["watt_max"], sock.current_watt)
                cache["last_kwh"] = r["energy_kwh"]

            # تشغيل محرك القواعد والحماية التلقائية
            for rule_func in PROTECTION_AND_AUTOMATION_RULES:
                tripped_all = await rule_func(session, db, strip, sockets_map, total_watt, total_amp)
                if tripped_all:
                    break

            strip.last_seen = utc_now()
            db.commit()

            # بث التحديث اللحظي لجميع المتصفحات وتطبيقات الموبايل المتصلة بالـ WebSocket
            total_kwh = sum(round(max(0.0, s.raw_energy_kwh - s.energy_baseline_kwh), 3) for s in strip.sockets)
            await self.broadcast_update(strip.mac_address, {
                "system": settings.PROJECT_NAME,
                "event": "telemetry_update",
                "mac": strip.mac_address,
                "name": strip.strip_name,
                "model": strip.model,
                "fw": strip.fw_version,
                "ip": strip.ip_address,
                "online": strip.is_online,
                "voltage": strip.current_voltage,
                "rssi": strip.wifi_rssi,
                "child_lock": strip.child_lock,
                "voltage_exempt_sockets": getattr(strip, "voltage_exempt_sockets", "2,4"),
                "voltage_recover_delay_sec": getattr(strip, "voltage_recover_delay_sec", 180),
                "voltage_breach_count": getattr(strip, "voltage_breach_count", 0),
                "disconnect_count": getattr(strip, "disconnect_count", 0),
                "power_return_state": getattr(strip, "power_return_state", "LAST"),
                "biometric_control": getattr(strip, "biometric_control", False),
                "total_watt": round(total_watt, 2),
                "total_amp": round(total_amp, 3),
                "total_kwh": round(total_kwh, 3),
                "total_cost_egp": round(total_kwh * rate, 2),
                "sockets": [
                    {
                        "id": s.id,
                        "index": s.socket_index,
                        "name": s.name,
                        "icon": s.icon,
                        "color_hex": getattr(s, "color_hex", "#10B981") or "#10B981",
                        "link_group": getattr(s, "link_group", 0) or 0,
                        "doorbell_mode": bool(getattr(s, "doorbell_mode", False)),
                        "doorbell_pulse_sec": getattr(s, "doorbell_pulse_sec", 3) or 3,
                        "is_pinned_state": bool(getattr(s, "is_pinned_state", False)),
                        "alert_watt_threshold": getattr(s, "alert_watt_threshold", None),
                        "auto_off_delay_sec": getattr(s, "auto_off_delay_sec", None),
                        "is_router": s.is_router,
                        "is_locked": bool(getattr(s, "is_locked", False)),
                        "is_favorite": s.is_favorite,
                        "on": s.reported_state,
                        "watt": s.current_watt,
                        "amp": s.current_amp,
                        "temp_c": s.current_temp_c,
                        "max_watt_limit": s.max_watt_limit,
                        "min_watt_cutoff": s.min_watt_cutoff,
                        "cutoff_delay_sec": s.cutoff_delay_sec,
                        "compressor_protect": s.compressor_protect,
                        "compressor_delay_sec": s.compressor_delay_sec,
                        "master_socket_id": s.master_socket_id,
                        "master_trigger_watt": s.master_trigger_watt,
                        "kwh": round(max(0.0, s.raw_energy_kwh - s.energy_baseline_kwh), 3),
                        "cost_egp": round(max(0.0, s.raw_energy_kwh - s.energy_baseline_kwh) * rate, 2),
                    }
                    for s in sorted(strip.sockets, key=lambda x: x.socket_index)
                ],
            })
        finally:
            db.close()

    async def evaluate_voltage(self, session: StripSession, voltage_v: float) -> None:
        """مراقبة الجهد اللحظي مع احترام المخارج المستثناة ومهلة الاسترجاع بعد استقرار الكهرباء"""
        if not session.mac:
            return
        db = SessionLocal()
        try:
            strip = find_strip_by_mac(db, session.mac)
            if not strip:
                return

            strip.current_voltage = voltage_v

            if strip.voltage_protect_enabled:
                min_v = strip.min_voltage or 185.0
                max_v = strip.max_voltage or 245.0

                # استخراج قائمة المخارج المستثناة من فصل الفولت (مثل الراوتر والمثبّت)
                exempt_raw = getattr(strip, "voltage_exempt_sockets", "2,4") or ""
                exempt_set = set()
                for part in str(exempt_raw).split(","):
                    part = part.strip()
                    if part.isdigit():
                        exempt_set.add(int(part))
                for s in strip.sockets:
                    if s.is_router or getattr(s, "is_pinned_state", False):
                        exempt_set.add(s.socket_index)

                if voltage_v < min_v or voltage_v > max_v:
                    session.consecutive_voltage_faults += 1
                    session.voltage_recovery_streak = 0
                    session.voltage_recovery_started_at = None

                    if session.consecutive_voltage_faults >= 2 and not session.voltage_tripped:
                        strip.voltage_breach_count = (getattr(strip, "voltage_breach_count", 0) or 0) + 1
                        trip_targets = [
                            s.socket_index
                            for s in strip.sockets
                            if s.reported_state and s.socket_index not in exempt_set
                        ]
                        strip.pre_trip_state = json.dumps(trip_targets)
                        session.voltage_tripped = True

                        if trip_targets:
                            asyncio.create_task(session.set_outlets(trip_targets, False, stagger_sec=0.15))
                        log_event(
                            db, strip.id, 0, "VOLTAGE_TRIP", "PROTECTION",
                            f"فصل طوارئ الفولت ({voltage_v}V خارج {min_v}V-{max_v}V) للمخارج {trip_targets} مع استثناء {sorted(list(exempt_set))}"
                        )
                        await self.broadcast_update(strip.mac_address, {
                            "event": "voltage_trip",
                            "voltage": voltage_v,
                            "tripped_sockets": trip_targets,
                            "exempt_sockets": sorted(list(exempt_set)),
                            "message": f"تم فصل المخارج غير المستثناة بسبب تذبذب الجهد ({voltage_v}V)"
                        })
                else:
                    session.consecutive_voltage_faults = 0

                    if session.voltage_tripped and strip.auto_recover_voltage:
                        session.voltage_recovery_streak += 1
                        if session.voltage_recovery_started_at is None:
                            session.voltage_recovery_started_at = utc_now()

                        recover_delay = max(15, getattr(strip, "voltage_recover_delay_sec", 180) or 180)
                        elapsed_stable = (utc_now() - session.voltage_recovery_started_at).total_seconds()

                        if session.voltage_recovery_streak >= 2 and elapsed_stable >= recover_delay:
                            pre_sockets = []
                            try:
                                pre_sockets = json.loads(strip.pre_trip_state or "[]")
                            except Exception:
                                pre_sockets = []

                            session.voltage_tripped = False
                            session.voltage_recovery_streak = 0
                            session.voltage_recovery_started_at = None

                            if pre_sockets:
                                asyncio.create_task(session.set_outlets(pre_sockets, True, stagger_sec=0.8))
                                log_event(
                                    db, strip.id, 0, "VOLTAGE_RECOVER", "PROTECTION",
                                    f"استقرار الجهد عند {voltage_v}V لمدة {int(elapsed_stable)}s واستعادة الفيش: {pre_sockets}"
                                )
                                await self.broadcast_update(strip.mac_address, {
                                    "event": "voltage_recovered",
                                    "voltage": voltage_v,
                                    "message": "استقر الجهد وتمت استعادة تشغيل أجهزتك بنجاح"
                                })

            db.commit()
        finally:
            db.close()

    async def handle_physical_button(self, session: StripSession, ch: int, is_on: bool) -> None:
        """معالجة الضغط اليدوي على زر المشترك مع دعم قفل الأطفال الفردي للمخرج المقفول وتثبيت الحالة وربط المجموعات ووضع الجرس"""
        if not session.mac:
            return
        db = SessionLocal()
        try:
            strip = find_strip_by_mac(db, session.mac)
            if not strip:
                return

            # 1. التحقق من تثبيت الحالة (Pin State Guard) وقفل المخرج الفردي/الأطفال (Per-Outlet Lock & Child Guard) عند الضغط اليدوي
            if ch in (1, 2, 3, 4):
                target_sock = next((s for s in strip.sockets if s.socket_index == ch), None)
                if target_sock and getattr(target_sock, "is_pinned_state", False) and is_on != target_sock.desired_state:
                    asyncio.create_task(session.set_outlets([ch], target_sock.desired_state))
                    log_event(
                        db, strip.id, ch, "PIN_STATE_GUARD", "PROTECTION",
                        f"منع تغيير المخرج {ch} ({target_sock.name}) يدوياً لأن حالته مثبّتة على {'تشغيل' if target_sock.desired_state else 'إيقاف'}"
                    )
                    db.commit()
                    await self.broadcast_update(strip.mac_address, {
                        "event": "pin_state_blocked",
                        "socket_index": ch,
                        "message": f"المخرج '{target_sock.name}' مثبّت على حالته الحالية ولا يمكن تغييره قبل إلغاء التثبيت"
                    })
                    return

                if target_sock and getattr(target_sock, "is_locked", False) and is_on != target_sock.desired_state:
                    asyncio.create_task(session.set_outlets([ch], target_sock.desired_state))
                    log_event(
                        db, strip.id, ch, "LOCKED_OUTLET_CHILD_GUARD", "PROTECTION",
                        f"منع تغيير المخرج {ch} ({target_sock.name}) من الزر الفيزيائي لأن قفل المخرج وقفل الأطفال الفردي مفعل عليه 🔒"
                    )
                    db.commit()
                    await self.broadcast_update(strip.mac_address, {
                        "event": "locked_outlet_physical_blocked",
                        "socket_index": ch,
                        "message": f"تم حماية المخرج '{target_sock.name}' من الضغط اليدوي لأن قفل المخرج/الأطفال مفعل عليه 🔒"
                    })
                    return

            # 2. تحديث حالة المخارج المتأثرة وفحص ربط المجموعات (Link Group) ووضع الجرس (Doorbell)
            linked_group_to_sync = 0
            for sock in strip.sockets:
                if ch == 0 or sock.socket_index == ch:
                    if ch == 0 and (getattr(sock, "is_pinned_state", False) or getattr(sock, "is_locked", False)) and is_on != sock.desired_state:
                        # استرجاع المخرج المثبت أو المقفول إذا ضغط المستخدم الزر الرئيسي على المشترك
                        asyncio.create_task(session.set_outlets([sock.socket_index], sock.desired_state))
                        continue
                    sock.reported_state = is_on
                    sock.desired_state = is_on
                    if not is_on:
                        sock.current_watt = 0.0
                        sock.current_amp = 0.0
                        sock.last_off_timestamp = utc_now()
                    if ch in (1, 2, 3, 4):
                        lg = getattr(sock, "link_group", 0) or 0
                        if lg in (1, 2, 3, 4):
                            linked_group_to_sync = lg
                        if getattr(sock, "doorbell_mode", False) and is_on:
                            pulse = getattr(sock, "doorbell_pulse_sec", 3) or 3
                            asyncio.create_task(self.trigger_doorbell_auto_off(strip.mac_address, ch, pulse))

            # مزامنة باقي مخارج المجموعة المربوطة (Link Group 1..4)
            if linked_group_to_sync in (1, 2, 3, 4):
                linked_indices = []
                for s in strip.sockets:
                    if s.socket_index != ch and (getattr(s, "link_group", 0) == linked_group_to_sync):
                        if getattr(s, "is_pinned_state", False) or getattr(s, "is_locked", False):
                            continue
                        if not is_on and s.is_router:
                            continue
                        s.desired_state = is_on
                        s.reported_state = is_on
                        if not is_on:
                            s.current_watt = 0.0
                            s.current_amp = 0.0
                            s.last_off_timestamp = utc_now()
                        linked_indices.append(s.socket_index)
                if linked_indices:
                    asyncio.create_task(session.set_outlets(linked_indices, is_on, stagger_sec=0.15))

            log_event(db, strip.id, ch, "ON" if is_on else "OFF", "PHYSICAL_BUTTON", "تغيير يدوي من زر المشترك")
            db.commit()

            asyncio.create_task(session.refresh())
        finally:
            db.close()

    async def handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        """إدارة دورة حياة اتصال العميل والمشترك"""
        peer = writer.get_extra_info("peername")
        ip = peer[0] if peer else "?"
        session = StripSession(ip, reader, writer)
        print(f"[{settings.PROJECT_NAME} TCP] New connection from {mask_ip(ip)}")

        try:
            while True:
                raw = await reader.readline()
                if not raw:
                    break
                if len(raw) > 8192:
                    raise ValueError("Line too long")

                line = raw.replace(b"\x00", b"").decode("utf-8", "replace").strip("\r\n ")
                session.last_rx = line

                m = BOOTINFO_RE.match(line)
                if m:
                    model, mac, _, fw = m.group(1), m.group(2).upper(), m.group(3), m.group(4)
                    session.mac = mac
                    session.model = model
                    session.fw_version = fw

                    old = self.sessions.get(mac)
                    if old and old is not session:
                        old.writer.close()
                    self.sessions[mac] = session

                    db = SessionLocal()
                    try:
                        strip = find_strip_by_mac(db, mac)
                        if not strip:
                            print(f"[{settings.PROJECT_NAME} TCP] ℹ️ Device {mask_mac(mac)} from {mask_ip(ip)} is not claimed by any user yet (ready in memory).")
                        else:
                            strip.model, strip.fw_version, strip.ip_address = model, fw, ip
                            strip.is_online = True
                            strip.last_seen = utc_now()
                            db.commit()
                        session.strip_id = strip.id if strip else None
                    finally:
                        db.close()

                    print(f"[{settings.PROJECT_NAME} TCP] ✅ Client {mask_mac(mac)} securely connected (fw={fw})")
                    asyncio.create_task(session.refresh())
                    asyncio.create_task(session.query_diagnostics())
                    db_check = SessionLocal()
                    try:
                        st = find_strip_by_mac(db_check, mac)
                        if st and st.child_lock:
                            asyncio.create_task(session.set_child_lock(True))
                        elif st and not st.child_lock:
                            asyncio.create_task(session.set_child_lock(False))
                    finally:
                        db_check.close()
                    continue

                if not session.mac:
                    continue

                if line.startswith("up:getinfo:"):
                    records = parse_getinfo(line)
                    if len(records) == 4:
                        session.got_getinfo.set()
                        await self.process_telemetry(session, records)
                    continue

                if line.lower().startswith("up:power_report:"):
                    m = POWER_REPORT_RE.fullmatch(line)
                    if m and int(m.group(2)) >= 50000:
                        await self.evaluate_voltage(session, round(int(m.group(2)) / 1000.0, 1))
                    continue

                m = QUERY_RE.fullmatch(line)
                if m:
                    db = SessionLocal()
                    try:
                        strip = find_strip_by_mac(db, session.mac)
                        if strip:
                            strip.wifi_rssi = int(m.group(1))
                            db.commit()
                    finally:
                        db.close()
                    continue

                m = EVENT_RE.fullmatch(line)
                if m:
                    await self.handle_physical_button(session, int(m.group(1)), m.group(2).lower() == "on")
                    continue

                cl_mask = parse_childlock_line(line)
                if cl_mask is not None:
                    session.last_childlock_mask = cl_mask
                    session.got_childlock.set()
                    is_locked = (cl_mask == 31)
                    print(f"[{settings.PROJECT_NAME} TCP] 🔒 Child lock hardware state confirmed for {mask_mac(session.mac)}: mask={cl_mask} (locked={is_locked})")
                    db = SessionLocal()
                    try:
                        strip = find_strip_by_mac(db, session.mac)
                        if strip and strip.child_lock != is_locked:
                            strip.child_lock = is_locked
                            db.commit()
                            asyncio.create_task(self.broadcast_update(strip.mac_address, {
                                "event": "protection_update",
                                "mac": strip.mac_address,
                                "child_lock": is_locked,
                            }))
                    finally:
                        db.close()
                    continue

                m = ONOFF_ACK_RE.fullmatch(line)
                if m:
                    continue

        except (ConnectionResetError, BrokenPipeError, asyncio.IncompleteReadError):
            pass
        except Exception as err:
            print(f"[{settings.PROJECT_NAME} TCP] خطأ جلسة {mask_ip(ip)}: {err!r}")
        finally:
            if session.mac and self.sessions.get(session.mac) is session:
                self.sessions.pop(session.mac, None)
                db = SessionLocal()
                try:
                    strip = find_strip_by_mac(db, session.mac)
                    if strip:
                        strip.is_online = False
                        strip.disconnect_count = (getattr(strip, "disconnect_count", 0) or 0) + 1
                        strip.last_disconnect_at = utc_now()
                        db.commit()
                finally:
                    db.close()
                print(f"[{settings.PROJECT_NAME} TCP] Client {mask_mac(session.mac)} is offline")
                await self.broadcast_update(session.mac, {"event": "status_change", "mac": session.mac, "online": False})

            writer.close()
            try:
                await writer.wait_closed()
            except Exception:
                pass

    def flush_energy_cache_to_db(self) -> None:
        """حفظ إحصائيات الطاقة التراكمية في قاعدة البيانات دورياً"""
        if not self.hourly_energy_cache:
            return
        db = SessionLocal()
        try:
            now = utc_now()
            for socket_id, data in list(self.hourly_energy_cache.items()):
                if data["count"] == 0:
                    continue
                sock = db.query(Socket).filter(Socket.id == socket_id).first()
                if not sock:
                    continue
                rate = sock.strip.owner.electricity_rate_egp if (sock.strip and sock.strip.owner and sock.strip.owner.electricity_rate_egp) else 1.45
                watt_avg = round(data["watt_sum"] / data["count"], 2)
                kwh_delta = round(max(0.0, data["last_kwh"] - data["start_kwh"]), 4)
                db.add(EnergyLog(
                    socket_id=socket_id,
                    period_start=now,
                    period_type="HOURLY",
                    watt_avg=watt_avg,
                    watt_max=data["watt_max"],
                    kwh_delta=kwh_delta,
                    estimated_cost_egp=round(kwh_delta * rate, 3),
                ))
                self.hourly_energy_cache[socket_id] = {
                    "watt_sum": 0.0, "count": 0, "watt_max": 0.0,
                    "start_kwh": data["last_kwh"], "last_kwh": data["last_kwh"]
                }
            db.commit()
        finally:
            db.close()

    def sweep_stale_offline_strips(self) -> None:
        """فحص المشتركات التي لم ترسل نبضات منذ أكثر من 90 ثانية وتحويلها لأوفلاين"""
        db = SessionLocal()
        try:
            from datetime import timedelta
            cutoff = utc_now() - timedelta(seconds=90)
            stale_strips = db.query(Strip).filter(Strip.is_online == True, Strip.last_seen < cutoff).all()
            for st in stale_strips:
                if st.mac_address not in self.sessions:
                    st.is_online = False
                    st.disconnect_count = (getattr(st, "disconnect_count", 0) or 0) + 1
                    st.last_disconnect_at = utc_now()
                    print(f"[{settings.PROJECT_NAME} TCP] ⚠️ Marked stale strip {mask_mac(st.mac_address)} as offline (timeout > 90s)")
            if stale_strips:
                db.commit()
        except Exception as e:
            print(f"[{settings.PROJECT_NAME} TCP] Sweep notice: {e}")
        finally:
            db.close()

    async def poll_loop(self) -> None:
        """حلقة الاستطلاع الدورية الرئيسية كل 5 ثوانٍ وكشف الأوفلاين"""
        cycle = 0
        while True:
            cycle += 1
            for session in list(self.sessions.values()):
                if not session.mac:
                    continue
                try:
                    if await session.refresh() and cycle % settings.DIAG_EVERY_N_POLLS == 0:
                        await session.query_diagnostics()
                except Exception:
                    pass
            if cycle % 180 == 0:
                self.flush_energy_cache_to_db()

            if cycle % 12 == 0:
                self.sweep_stale_offline_strips()

            await asyncio.sleep(settings.POLL_INTERVAL_SEC)


na7la_hub = Na7laTCPHub()
