import asyncio
from datetime import datetime, timezone
from typing import Callable, List, Dict, Tuple, Optional
from sqlalchemy.orm import Session
from models import Strip, Socket, AuditLog
from config import settings

# قائمة القواعد المسجلة تلقائياً في النظام
PROTECTION_AND_AUTOMATION_RULES: List[Callable] = []

# عدادات الذاكرة لتطبيق قاعدة التأكيد المزدوج (2-Consecutive Strikes) دون الضغط على الداتابيز
_socket_watt_strikes: Dict[Tuple[int, int], int] = {}
_total_load_strikes: Dict[int, int] = {}
_thermal_strikes: Dict[int, int] = {}
_idle_start_time: Dict[Tuple[int, int], datetime] = {}
_watt_alert_last_sent: Dict[Tuple[int, int], datetime] = {}


def register_rule(func: Callable) -> Callable:
    """مُزخرف (Decorator) لتسجيل أي ميزة حماية أو أتمتة جديدة تلقائياً"""
    PROTECTION_AND_AUTOMATION_RULES.append(func)
    return func


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def log_event(db: Session, strip_id: int, socket_idx: Optional[int], action: str, triggered_by: str, reason: str):
    """توثيق الأحداث ومسببات الفصل في الصندوق الأسود (AuditLog)"""
    db.add(AuditLog(
        strip_id=strip_id,
        socket_index=socket_idx,
        action=action,
        triggered_by=triggered_by,
        reason_details=reason,
    ))


# ==============================================================================
# 1. قاعدة حماية المقبس الفردي من السحب الزائد (Per-Socket Max Watt - 2 Strikes)
# ==============================================================================
@register_rule
async def rule_per_socket_watt_protection(session, db: Session, strip: Strip, sockets_map: dict, total_watt: float, total_amp: float) -> bool:
    """فصل المخرج الفردي فقط إذا تجاوز حده المسموح لقراءتين متتاليتين مع ترك باقي الأجهزة تعمل"""
    for idx, sock in sockets_map.items():
        if not sock.reported_state:
            _socket_watt_strikes.pop((strip.id, idx), None)
            continue

        limit = sock.max_watt_limit or 2500.0
        key = (strip.id, idx)

        if sock.current_watt > limit:
            strikes = _socket_watt_strikes.get(key, 0) + 1
            _socket_watt_strikes[key] = strikes

            if strikes >= 2:
                # فصل هذا المقبس المخالف وحده فقط
                asyncio.create_task(session.set_outlets([idx], False))
                sock.desired_state = False
                _socket_watt_strikes[key] = 0
                log_event(
                    db, strip.id, idx, "TRIP_WATT_LIMIT", "PROTECTION",
                    f"فصل أمان: سحب المخرج ({sock.current_watt}W) تجاوز الحد المسموح ({limit}W) لقراءتين متتاليتين"
                )
        else:
            _socket_watt_strikes[key] = 0

    return False


# ==============================================================================
# 2. قاعدة إسقاط الأحمال الذكي وحماية الحمل الإجمالي (Smart Load Shedding)
# ==============================================================================
@register_rule
async def rule_total_load_and_smart_shedding(session, db: Session, strip: Strip, sockets_map: dict, total_watt: float, total_amp: float) -> bool:
    """إسقاط الفيشة الأعلى سحباً بدلاً من إطفاء المشترك كاملاً عند الخطر (مع حماية الراوتر)"""
    max_w = strip.max_total_watt or 3000.0
    max_a = strip.max_total_amp or 16.0
    s_id = strip.id

    # 1. طوارئ قصوى فورية (Short-Circuit / Danger Spike): فصل الكل لمنع الحريق
    if total_watt >= settings.EMERGENCY_MAX_WATT or total_amp >= settings.EMERGENCY_MAX_AMP:
        asyncio.create_task(session.set_outlets([1, 2, 3, 4], False, stagger_sec=0.1))
        for s in sockets_map.values():
            s.desired_state = False
        log_event(
            db, strip.id, 0, "EMERGENCY_SHUTDOWN", "PROTECTION",
            f"طوارئ قصوى: الحمل الإجمالي قفز فجأة ({round(total_watt, 1)}W / {round(total_amp, 2)}A) - فصل فوري لكافة المخارج"
        )
        return True

    # 2. الحمل الزائد المستمر (2-Consecutive Strikes)
    if total_watt > max_w or total_amp > max_a:
        strikes = _total_load_strikes.get(s_id, 0) + 1
        _total_load_strikes[s_id] = strikes

        if strikes >= 2:
            _total_load_strikes[s_id] = 0

            # ميزة إسقاط الأحمال الذكي: البحث عن أعلى فيشة سحباً واستبعاد الراوتر والمخارج المثبتة
            if strip.auto_shedding_enabled:
                candidates = [
                    s for s in sockets_map.values()
                    if s.reported_state and not s.is_router and not getattr(s, "is_pinned_state", False)
                ]
                if candidates:
                    candidates.sort(key=lambda x: x.current_watt, reverse=True)
                    top_dev = candidates[0]
                    asyncio.create_task(session.set_outlets([top_dev.socket_index], False))
                    top_dev.desired_state = False
                    log_event(
                        db, strip.id, top_dev.socket_index, "SMART_SHEDDING", "PROTECTION",
                        f"إسقاط أحمال ذكي: فصل مخرج '{top_dev.name}' ({top_dev.current_watt}W) لحماية المشترك والراوتر من الحمل الإجمالي ({round(total_watt, 1)}W)"
                    )
                    return False

            # إذا كان إسقاط الأحمال معطلاً: فصل المخارج غير المحمية
            non_routers = [s.socket_index for s in sockets_map.values() if s.reported_state and not s.is_router]
            if non_routers:
                asyncio.create_task(session.set_outlets(non_routers, False, stagger_sec=0.15))
                for idx in non_routers:
                    if idx in sockets_map:
                        sockets_map[idx].desired_state = False
                log_event(
                    db, strip.id, 0, "OVERLOAD_SHUTDOWN", "PROTECTION",
                    f"فصل الحمل الزائد الإجمالي ({round(total_watt, 1)}W) مع الحفاظ على الراوتر قيد التشغيل"
                )
                return True
    else:
        _total_load_strikes[s_id] = 0

    return False


# ==============================================================================
# 3. قاعدة فصل الشواحن التلقائي والخمول (Charger Cutoff / Idle Guard)
# ==============================================================================
@register_rule
async def rule_idle_and_charger_cutoff(session, db: Session, strip: Strip, sockets_map: dict, total_watt: float, total_amp: float) -> bool:
    """فصل المخرج تلقائياً إذا هبط السحب تحت حد معين (مثل 3W) لمهلة محددة (اكتمال شحن البطارية)"""
    now = utc_now()
    for idx, sock in sockets_map.items():
        key = (strip.id, idx)
        min_limit = sock.min_watt_cutoff

        if sock.reported_state and min_limit is not None and min_limit > 0:
            if sock.current_watt < min_limit:
                if key not in _idle_start_time:
                    _idle_start_time[key] = now
                else:
                    elapsed_sec = (now - _idle_start_time[key]).total_seconds()
                    delay_needed = sock.cutoff_delay_sec or 600

                    if elapsed_sec >= delay_needed:
                        asyncio.create_task(session.set_outlets([idx], False))
                        sock.desired_state = False
                        _idle_start_time.pop(key, None)
                        mins = int(elapsed_sec / 60)
                        log_event(
                            db, strip.id, idx, "CHARGER_CUTOFF", "AUTOMATION",
                            f"فصل تلقائي لاكتمال الشحن: استهلاك '{sock.name}' أقل من {min_limit}W لمدة {mins} دقيقة"
                        )
            else:
                _idle_start_time.pop(key, None)
        else:
            _idle_start_time.pop(key, None)

    return False


# ==============================================================================
# 4. قاعدة الحماية الحرارية الموزونة (Thermal Protection - Real °C)
# ==============================================================================
@register_rule
async def rule_thermal_protection(session, db: Session, strip: Strip, sockets_map: dict, total_watt: float, total_amp: float) -> bool:
    """فصل المشترك إذا تجاوزت درجة الحرارة السيليزيوس الحقيقية الحد الآمن"""
    s_id = strip.id
    max_safe_temp = strip.max_temp_c or 65
    current_temps = [s.current_temp_c for s in sockets_map.values() if s.current_temp_c > 0]
    peak_temp = max(current_temps) if current_temps else 0

    # 1. طوارئ قصوى: إذا وصلت الحرارة 75°C فصل فوري
    if peak_temp >= 75:
        asyncio.create_task(session.set_outlets([1, 2, 3, 4], False, stagger_sec=0.1))
        for s in sockets_map.values():
            s.desired_state = False
        log_event(
            db, strip.id, 0, "EMERGENCY_TEMP", "PROTECTION",
            f"طوارئ حرارية قصوى: الحرارة بلغت {peak_temp}°C - فصل فوري لكافة المخارج لمنع انصهار المشترك"
        )
        return True

    # 2. تجاوز حد المستخدم لقراءتين متتاليتين
    if peak_temp > max_safe_temp:
        strikes = _thermal_strikes.get(s_id, 0) + 1
        _thermal_strikes[s_id] = strikes

        if strikes >= 2:
            _thermal_strikes[s_id] = 0
            asyncio.create_task(session.set_outlets([1, 2, 3, 4], False, stagger_sec=0.15))
            for s in sockets_map.values():
                s.desired_state = False
            log_event(
                db, strip.id, 0, "THERMAL_TRIP", "PROTECTION",
                f"فصل أمان حراري: الحرارة ({peak_temp}°C) تجاوزت الحد المسموح ({max_safe_temp}°C) لقراءتين متتاليتين"
            )
            return True
    else:
        _thermal_strikes[s_id] = 0

    return False


# ==============================================================================
# 5. قاعدة الترابط الشرطي التلقائي (Master-Slave Sync)
# ==============================================================================
@register_rule
async def rule_master_slave_sync(session, db: Session, strip: Strip, sockets_map: dict, total_watt: float, total_amp: float) -> bool:
    """تشغيل وإطفاء المقابس التابعة تلقائياً عند تغيير حالة وسحب المقبس الرئيسي"""
    for idx, sock in sockets_map.items():
        if sock.master_socket_id:
            master = next((m for m in sockets_map.values() if m.id == sock.master_socket_id), None)
            if master:
                # الفيشة التابعة تفتح فقط إذا كان الماستر شغّال ويسحب واط أعلى من عتبة التشغيل
                threshold = sock.master_trigger_watt or 20.0
                should_be_on = master.reported_state and (master.current_watt >= threshold)

                if should_be_on != sock.reported_state:
                    asyncio.create_task(session.set_outlets([idx], should_be_on))
                    sock.desired_state = should_be_on
                    log_event(
                        db, strip.id, idx, "ON" if should_be_on else "OFF", "MASTER_SLAVE",
                        f"تبعية تلقائية: للمقبس الرئيسي رقم {master.socket_index} '{master.name}' (سحبه: {master.current_watt}W)"
                    )

    return False


# ==============================================================================
# 6. قاعدة التنبيه الذكي للسحب بدون فصل (Alert at W - Notification Only)
# ==============================================================================
@register_rule
async def rule_per_socket_watt_alert(session, db: Session, strip: Strip, sockets_map: dict, total_watt: float, total_amp: float) -> bool:
    """إصدار تنبيه في السجل والإشعارات عند تجاوز المخرج عتبة الواط المحددة دون فصل التيار"""
    now = utc_now()
    for idx, sock in sockets_map.items():
        key = (strip.id, idx)
        alert_w = getattr(sock, "alert_watt_threshold", None)
        if sock.reported_state and alert_w is not None and alert_w > 0:
            if sock.current_watt >= alert_w:
                last_sent = _watt_alert_last_sent.get(key)
                if not last_sent or (now - last_sent).total_seconds() >= 300:
                    _watt_alert_last_sent[key] = now
                    log_event(
                        db, strip.id, idx, "WATT_ALERT", "PROTECTION",
                        f"تنبيه سحب عالي: المخرج '{sock.name}' يسحب حالياً {sock.current_watt}W (تجاوز حد التنبيه {alert_w}W بدون فصل)"
                    )
            else:
                _watt_alert_last_sent.pop(key, None)
        else:
            _watt_alert_last_sent.pop(key, None)
    return False
