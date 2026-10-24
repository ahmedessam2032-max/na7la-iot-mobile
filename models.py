from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import (
    Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text, UniqueConstraint, event
)
from sqlalchemy.orm import relationship, Session
from database import Base
from crypto_utils import EncryptedText, compute_blind_index, normalize_mac


def utc_now():
    return datetime.now(timezone.utc)


class User(Base):
    """جدول المستخدمين وإعدادات الأمان والتعرفة الإقليمية (تشفير AES-256-GCM للبيانات الشخصية)"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    google_uid = Column(EncryptedText, nullable=True)
    google_blind_index = Column(String(64), unique=True, index=True, nullable=True)
    email = Column(EncryptedText, nullable=False)
    email_blind_index = Column(String(64), unique=True, index=True, nullable=True)
    password_hash = Column(String(255), nullable=True)
    full_name = Column(EncryptedText, nullable=True)
    role = Column(String(20), default="USER")  # ADMIN / USER
    plan_name = Column(String(20), default="FREE")  # FREE (1 strip) / PRO (15 strips) / ADMIN
    max_strips = Column(Integer, default=1)  # الحد الأقصى للمشتركات المسموح بربطها

    # حماية التطبيق الإضافية
    pin_code_hash = Column(String(255), nullable=True)
    biometric_enabled = Column(Boolean, default=False)
    token_version = Column(Integer, default=1)

    # الإعدادات الإقليمية وحساب التكلفة
    language = Column(String(5), default="ar")  # ar / en
    timezone = Column(String(50), default="Africa/Cairo")
    currency = Column(String(10), default="EGP")
    electricity_rate_egp = Column(Float, default=1.45)
    tariff_mode = Column(String(20), default="TIERS")  # TIERS (شرائح الكهرباء المصرية) / FLAT (سعر موحد)
    notif_prefs_json = Column(EncryptedText, nullable=True)  # تفضيلات الإشعارات مشفرة

    # قنوات الإشعارات والتكامل الخارجي (مشفرة بالكامل)
    fcm_token = Column(EncryptedText, nullable=True)
    telegram_chat_id = Column(EncryptedText, nullable=True)
    webhook_token = Column(EncryptedText, nullable=True)
    webhook_blind_index = Column(String(64), unique=True, index=True, nullable=True)

    created_at = Column(DateTime(timezone=True), default=utc_now)

    # العلاقات
    strips = relationship("Strip", back_populates="owner", cascade="all, delete-orphan")
    scenes = relationship("Scene", back_populates="user", cascade="all, delete-orphan")


class Strip(Base):
    """جدول المشتركات الذكية (MTTL-W01) مع تشفير الـ MAC والـ IP والاسم وعزل الهوية بـ Blind Index"""
    __tablename__ = "strips"

    id = Column(Integer, primary_key=True, index=True)
    mac_blind_index = Column(String(64), unique=True, index=True, nullable=False)
    mac_address = Column(EncryptedText, nullable=False)
    owner_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    strip_name = Column(EncryptedText, default="مشترك ذكي")
    icon = Column(String(20), default="💻")
    room_category = Column(EncryptedText, default="office")

    # بيانات الهاردوير المستلمة من حزمة up:bootinfo
    model = Column(String(50), default="LGU+-TAP-HW002")
    fw_version = Column(String(20), default="1.0.66")
    ip_address = Column(EncryptedText, nullable=True)
    wifi_rssi = Column(Integer, nullable=True)

    # حالة الاتصال اللحظية
    is_online = Column(Boolean, default=False)
    last_seen = Column(DateTime(timezone=True), nullable=True)
    current_voltage = Column(Float, nullable=True)

    # محرك الحماية الشامل للمشترك (قيم ديناميكية يحددها المستخدم)
    min_voltage = Column(Float, default=185.0)
    max_voltage = Column(Float, default=245.0)
    voltage_protect_enabled = Column(Boolean, default=True)
    auto_recover_voltage = Column(Boolean, default=True)
    voltage_exempt_sockets = Column(String(50), default="2,4")
    voltage_recover_delay_sec = Column(Integer, default=180)
    voltage_breach_count = Column(Integer, default=0)
    disconnect_count = Column(Integer, default=0)
    last_disconnect_at = Column(DateTime(timezone=True), nullable=True)
    power_return_state = Column(String(20), default="LAST")
    biometric_control = Column(Boolean, default=False)
    max_temp_c = Column(Integer, default=65)
    max_total_watt = Column(Float, default=3000.0)
    max_total_amp = Column(Float, default=16.0)

    # إسقاط الأحمال الذكي وحفظ حالة ما قبل أزمة الفولت
    auto_shedding_enabled = Column(Boolean, default=True)
    pre_trip_state = Column(EncryptedText, nullable=True)

    # أوضاع التشغيل والأمان الإضافي
    child_lock = Column(Boolean, default=False)
    away_mode_active = Column(Boolean, default=False)
    monthly_budget_kwh = Column(Float, nullable=True)
    pin_code_hash = Column(String(255), nullable=True)

    # نافذة الاقتران الآمن
    pairing_code = Column(EncryptedText, nullable=True)
    pairing_expires_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), default=utc_now)

    # العلاقات
    owner = relationship("User", back_populates="strips")
    sockets = relationship("Socket", back_populates="strip", cascade="all, delete-orphan")
    shared_users = relationship("SharedAccess", back_populates="strip", cascade="all, delete-orphan")
    audit_logs = relationship("AuditLog", back_populates="strip", cascade="all, delete-orphan")


class Socket(Base):
    """جدول المخارج الأربعة لكل مشترك (أسماء المخارج مشفرة بـ AES-256-GCM)"""
    __tablename__ = "sockets"
    __table_args__ = (UniqueConstraint("strip_id", "socket_index", name="uq_strip_socket_idx"),)

    id = Column(Integer, primary_key=True, index=True)
    strip_id = Column(Integer, ForeignKey("strips.id", ondelete="CASCADE"), nullable=False)
    socket_index = Column(Integer, nullable=False)  # 1, 2, 3, 4

    name = Column(EncryptedText, default="مقبس")
    icon = Column(String(50), default="power_plug")
    is_favorite = Column(Boolean, default=False)
    color_hex = Column(String(20), default="#10B981")

    # خصائص التحكم الذكي المتقدمة (WattQ + Na7la Exclusive)
    link_group = Column(Integer, default=0)
    doorbell_mode = Column(Boolean, default=False)
    doorbell_pulse_sec = Column(Integer, default=3)
    is_pinned_state = Column(Boolean, default=False)
    alert_watt_threshold = Column(Float, nullable=True)
    auto_off_delay_sec = Column(Integer, nullable=True)

    # حماية الراوتر والأجهزة الحيوية من الإطفاء بالخطأ
    is_router = Column(Boolean, default=False)
    is_locked = Column(Boolean, default=False)

    # توأم الحالة (Device Shadow)
    reported_state = Column(Boolean, default=False)
    desired_state = Column(Boolean, default=False)
    power_on_behavior = Column(String(10), default="LAST")

    # القراءات اللحظية
    current_watt = Column(Float, default=0.0)
    current_amp = Column(Float, default=0.0)
    current_temp_c = Column(Integer, default=0)
    runtime_seconds = Column(Integer, default=0)
    hw_overload_flag = Column(Boolean, default=False)
    hw_overheat_flag = Column(Boolean, default=False)

    # عداد الطاقة وميزة التصفير الآمن
    raw_energy_kwh = Column(Float, default=0.0)
    energy_baseline_kwh = Column(Float, default=0.0)

    # حدود الحماية الخاصة بالمخرج
    max_watt_limit = Column(Float, default=2500.0)
    min_watt_cutoff = Column(Float, nullable=True)
    cutoff_delay_sec = Column(Integer, default=600)
    compressor_protect = Column(Boolean, default=False)
    compressor_delay_sec = Column(Integer, default=180)
    last_off_timestamp = Column(DateTime(timezone=True), nullable=True)

    # الترابط الشرطي (Master-Slave) وأوقات الحظر
    master_socket_id = Column(Integer, ForeignKey("sockets.id", ondelete="SET NULL"), nullable=True)
    master_trigger_watt = Column(Float, default=20.0)
    quiet_hours_start = Column(String(5), nullable=True)
    quiet_hours_end = Column(String(5), nullable=True)

    # العلاقات
    strip = relationship("Strip", back_populates="sockets")
    schedules = relationship("Schedule", back_populates="socket", cascade="all, delete-orphan")
    energy_logs = relationship("EnergyLog", back_populates="socket", cascade="all, delete-orphan")


class Schedule(Base):
    """جدول الجدولة السحابية والمؤقتات بالأنماط الأربعة"""
    __tablename__ = "schedules"

    id = Column(Integer, primary_key=True, index=True)
    socket_id = Column(Integer, ForeignKey("sockets.id", ondelete="CASCADE"), nullable=False)
    schedule_type = Column(String(20), nullable=False)  # CRON / TIMER / CYCLE / AUTO_OFF

    cron_expr = Column(String(100), nullable=True)
    duration_sec = Column(Integer, nullable=True)
    cycle_on_sec = Column(Integer, nullable=True)
    cycle_off_sec = Column(Integer, nullable=True)
    auto_off_delay_sec = Column(Integer, nullable=True)

    target_state = Column(Boolean, nullable=False)
    hold_state = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    next_run_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=utc_now)

    socket = relationship("Socket", back_populates="schedules")


class Scene(Base):
    """جدول المشاهد المجمعة (الاسم والأوامر وعناوين MAC مشفرة بالكامل بـ AES-256-GCM)"""
    __tablename__ = "scenes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    scene_name = Column(EncryptedText, nullable=False)
    icon = Column(String(50), default="sparkles")
    stagger_delay_ms = Column(Integer, default=1500)
    actions_json = Column(EncryptedText, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utc_now)

    user = relationship("User", back_populates="scenes")


class SharedAccess(Base):
    """جدول مشاركة المشترك مع أفراد العائلة بأكواد دعوة مشفرة مع بصمة بحث عمياء"""
    __tablename__ = "shared_access"

    id = Column(Integer, primary_key=True, index=True)
    strip_id = Column(Integer, ForeignKey("strips.id", ondelete="CASCADE"), nullable=False)
    shared_with_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    member_name = Column(EncryptedText, default="فرد عائلة")
    permission_level = Column(String(20), default="FULL")  # FULL / PARTIAL / VIEW
    allowed_sockets = Column(String(50), default="1,2,3,4")
    is_active = Column(Boolean, default=True)
    invite_code = Column(EncryptedText, nullable=True)
    invite_blind_index = Column(String(64), unique=True, index=True, nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=utc_now)

    strip = relationship("Strip", back_populates="shared_users")
    shared_user = relationship("User", foreign_keys=[shared_with_user_id])


class EnergyLog(Base):
    """جدول سجل استهلاك الطاقة والتكلفة المجمع"""
    __tablename__ = "energy_logs"

    id = Column(Integer, primary_key=True, index=True)
    socket_id = Column(Integer, ForeignKey("sockets.id", ondelete="CASCADE"), nullable=False)
    period_start = Column(DateTime(timezone=True), index=True, nullable=False)
    period_type = Column(String(20), default="HOURLY")
    watt_avg = Column(Float, default=0.0)
    watt_max = Column(Float, default=0.0)
    kwh_delta = Column(Float, default=0.0)
    estimated_cost_egp = Column(Float, default=0.0)

    socket = relationship("Socket", back_populates="energy_logs")


class AuditLog(Base):
    """الصندوق الأسود لتوثيق الأوامر (التفاصيل والمنفذ مشفرون بـ AES-256-GCM)"""
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    strip_id = Column(Integer, ForeignKey("strips.id", ondelete="CASCADE"), nullable=False)
    socket_index = Column(Integer, nullable=True)
    action = Column(String(30), nullable=False)
    triggered_by = Column(EncryptedText, nullable=False)
    actor_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    reason_details = Column(EncryptedText, nullable=True)
    timestamp = Column(DateTime(timezone=True), index=True, default=utc_now)

    strip = relationship("Strip", back_populates="audit_logs")


class FirmwareRelease(Base):
    """جدول إدارة نسخ الفيرموير والتحقق من بصمة SHA-256"""
    __tablename__ = "firmware_releases"

    id = Column(Integer, primary_key=True, index=True)
    version_tag = Column(String(20), unique=True, nullable=False)
    filename = Column(String(100), nullable=False)
    file_size_bytes = Column(Integer, nullable=False)
    sha256_checksum = Column(String(64), nullable=False)
    release_notes = Column(Text, nullable=True)
    is_mandatory = Column(Boolean, default=False)
    uploaded_at = Column(DateTime(timezone=True), default=utc_now)


class PasswordReset(Base):
    """جدول أكواد التحقق السحابية (البريد مشفر + كود OTP مشفر باتجاه واحد HMAC-SHA256)"""
    __tablename__ = "password_resets"

    id = Column(Integer, primary_key=True, index=True)
    email_blind_index = Column(String(64), index=True, nullable=False)
    email = Column(EncryptedText, nullable=False)
    otp_code = Column(String(64), nullable=False)  # HMAC-SHA256 irreversible hash
    expires_at = Column(DateTime(timezone=True), nullable=False)
    is_used = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), default=utc_now)


class OutletRunSession(Base):
    """جدول سجل جلسات التشغيل التفصيلي لكل مخرج"""
    __tablename__ = "outlet_run_sessions"

    id = Column(Integer, primary_key=True, index=True)
    strip_id = Column(Integer, ForeignKey("strips.id", ondelete="CASCADE"), index=True, nullable=False)
    socket_id = Column(Integer, ForeignKey("sockets.id", ondelete="CASCADE"), index=True, nullable=False)
    socket_index = Column(Integer, nullable=False)
    socket_name = Column(EncryptedText, default="مقبس")
    started_at = Column(DateTime(timezone=True), index=True, default=utc_now)
    ended_at = Column(DateTime(timezone=True), nullable=True)
    duration_sec = Column(Integer, default=0)
    start_kwh = Column(Float, default=0.0)
    end_kwh = Column(Float, default=0.0)
    kwh_used = Column(Float, default=0.0)
    watt_sum = Column(Float, default=0.0)
    sample_count = Column(Integer, default=0)
    avg_watt = Column(Float, default=0.0)
    peak_watt = Column(Float, default=0.0)
    cost_egp = Column(Float, default=0.0)
    is_open = Column(Boolean, default=True, index=True)


class FeedbackSuggestion(Base):
    """جدول مقترحات المستخدمين وملاحظات الدعم الفني (مشفر بالكامل)"""
    __tablename__ = "feedback_suggestions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    email = Column(EncryptedText, nullable=True)
    message = Column(EncryptedText, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utc_now)


# ==============================================================================
# مزامنة البصمات العمياء تلقائياً (Automatic Blind-Index Lifecycle Hooks)
# ==============================================================================
def _sync_user_blind_indexes(mapper, connection, target: User):
    if target.email:
        target.email = target.email.strip().lower()
        target.email_blind_index = compute_blind_index("email", target.email)
    if target.google_uid:
        target.google_blind_index = compute_blind_index("google", target.google_uid)
    else:
        target.google_blind_index = None
    if target.webhook_token:
        target.webhook_blind_index = compute_blind_index("webhook", target.webhook_token)
    else:
        target.webhook_blind_index = None


def _sync_strip_blind_indexes(mapper, connection, target: Strip):
    if target.mac_address:
        clean = normalize_mac(target.mac_address)
        target.mac_address = clean
        target.mac_blind_index = compute_blind_index("mac", clean)


def _sync_share_blind_indexes(mapper, connection, target: SharedAccess):
    if target.invite_code:
        clean = target.invite_code.strip().upper()
        target.invite_code = clean
        target.invite_blind_index = compute_blind_index("invite", clean)
    else:
        target.invite_blind_index = None


def _sync_pwreset_blind_indexes(mapper, connection, target: PasswordReset):
    if target.email:
        clean = target.email.strip().lower()
        target.email = clean
        target.email_blind_index = compute_blind_index("email", clean)


event.listen(User, "before_insert", _sync_user_blind_indexes)
event.listen(User, "before_update", _sync_user_blind_indexes)
event.listen(Strip, "before_insert", _sync_strip_blind_indexes)
event.listen(Strip, "before_update", _sync_strip_blind_indexes)
event.listen(SharedAccess, "before_insert", _sync_share_blind_indexes)
event.listen(SharedAccess, "before_update", _sync_share_blind_indexes)
event.listen(PasswordReset, "before_insert", _sync_pwreset_blind_indexes)
event.listen(PasswordReset, "before_update", _sync_pwreset_blind_indexes)


# ==============================================================================
# دوال البحث الآمن عبر البصمات العمياء (Blind-Index Query Helpers)
# ==============================================================================
def find_user_by_email(db: Session, email: Optional[str]) -> Optional[User]:
    idx = compute_blind_index("email", email)
    if not idx:
        return None
    return db.query(User).filter(User.email_blind_index == idx).first()


def find_user_by_google_uid(db: Session, google_uid: Optional[str]) -> Optional[User]:
    idx = compute_blind_index("google", google_uid)
    if not idx:
        return None
    return db.query(User).filter(User.google_blind_index == idx).first()


def find_strip_by_mac(db: Session, mac: Optional[str]) -> Optional[Strip]:
    idx = compute_blind_index("mac", mac)
    if not idx:
        return None
    return db.query(Strip).filter(Strip.mac_blind_index == idx).first()


def find_share_by_invite_code(db: Session, invite_code: Optional[str], active_only: bool = True) -> Optional[SharedAccess]:
    idx = compute_blind_index("invite", invite_code)
    if not idx:
        return None
    q = db.query(SharedAccess).filter(SharedAccess.invite_blind_index == idx)
    if active_only:
        q = q.filter(SharedAccess.is_active == True)
    return q.first()
