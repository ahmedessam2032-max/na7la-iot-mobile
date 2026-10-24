from datetime import datetime, timezone
from sqlalchemy import (
    Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text, UniqueConstraint
)
from sqlalchemy.orm import relationship
from database import Base


def utc_now():
    return datetime.now(timezone.utc)


class User(Base):
    """جدول المستخدمين وإعدادات الأمان والتعرفة الإقليمية"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    google_uid = Column(String(128), unique=True, index=True, nullable=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=True)
    full_name = Column(String(150), nullable=True)
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
    notif_prefs_json = Column(Text, nullable=True)  # تفضيلات الإشعارات بصيغة JSON

    # قنوات الإشعارات والتكامل الخارجي
    fcm_token = Column(String(512), nullable=True)
    telegram_chat_id = Column(String(100), nullable=True)
    webhook_token = Column(String(128), unique=True, index=True, nullable=True)

    created_at = Column(DateTime(timezone=True), default=utc_now)

    # العلاقات
    strips = relationship("Strip", back_populates="owner", cascade="all, delete-orphan")
    scenes = relationship("Scene", back_populates="user", cascade="all, delete-orphan")


class Strip(Base):
    """جدول المشتركات الذكية (MTTL-W01) وإعدادات الحماية الشاملة الديناميكية"""
    __tablename__ = "strips"

    id = Column(Integer, primary_key=True, index=True)
    mac_address = Column(String(12), unique=True, index=True, nullable=False)
    owner_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    strip_name = Column(String(100), default="مشترك ذكي")
    icon = Column(String(20), default="💻")
    room_category = Column(String(50), default="office")

    # بيانات الهاردوير المستلمة من حزمة up:bootinfo
    model = Column(String(50), default="LGU+-TAP-HW002")
    fw_version = Column(String(20), default="1.0.66")
    ip_address = Column(String(45), nullable=True)
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
    voltage_exempt_sockets = Column(String(50), default="2,4")  # المخارج المستثناة من فصل الفولت (مثل الراوتر)
    voltage_recover_delay_sec = Column(Integer, default=180)  # مهلة الاسترجاع بعد استقرار الفولت بالثواني
    voltage_breach_count = Column(Integer, default=0)  # عدد مرات تجاوز الفولت
    disconnect_count = Column(Integer, default=0)  # عدد مرات انقطاع اتصال المشترك
    last_disconnect_at = Column(DateTime(timezone=True), nullable=True)  # آخر وقت انقطاع
    power_return_state = Column(String(20), default="LAST")  # LAST / ON / OFF (حالة العودة بعد انقطاع الكهرباء)
    biometric_control = Column(Boolean, default=False)  # قفل تحكم المشترك بالبصمة
    max_temp_c = Column(Integer, default=65)
    max_total_watt = Column(Float, default=3000.0)
    max_total_amp = Column(Float, default=16.0)

    # إسقاط الأحمال الذكي وحفظ حالة ما قبل أزمة الفولت
    auto_shedding_enabled = Column(Boolean, default=True)
    pre_trip_state = Column(Text, nullable=True)  # مصفوفة JSON للفيش التي كانت تعمل قبل الفصل

    # أوضاع التشغيل والأمان الإضافي
    child_lock = Column(Boolean, default=False)
    away_mode_active = Column(Boolean, default=False)
    monthly_budget_kwh = Column(Float, nullable=True)
    pin_code_hash = Column(String(255), nullable=True)

    # نافذة الاقتران الآمن
    pairing_code = Column(String(32), nullable=True)
    pairing_expires_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), default=utc_now)

    # العلاقات
    owner = relationship("User", back_populates="strips")
    sockets = relationship("Socket", back_populates="strip", cascade="all, delete-orphan")
    shared_users = relationship("SharedAccess", back_populates="strip", cascade="all, delete-orphan")
    audit_logs = relationship("AuditLog", back_populates="strip", cascade="all, delete-orphan")


class Socket(Base):
    """جدول المخارج الأربعة لكل مشترك وخصائص الحماية والترابط الشرطي وحماية الراوتر"""
    __tablename__ = "sockets"
    __table_args__ = (UniqueConstraint("strip_id", "socket_index", name="uq_strip_socket_idx"),)

    id = Column(Integer, primary_key=True, index=True)
    strip_id = Column(Integer, ForeignKey("strips.id", ondelete="CASCADE"), nullable=False)
    socket_index = Column(Integer, nullable=False)  # 1, 2, 3, 4

    name = Column(String(50), default="مقبس")
    icon = Column(String(50), default="power_plug")
    is_favorite = Column(Boolean, default=False)
    color_hex = Column(String(20), default="#10B981")  # لون المخرج من الـ 6 ألوان المخصصة

    # خصائص التحكم الذكي المتقدمة (WattQ + Na7la Exclusive)
    link_group = Column(Integer, default=0)  # 0=بدون ربط، 1..4=مجموعة ربط مخارج
    doorbell_mode = Column(Boolean, default=False)  # وضع الجرس اللحظي
    doorbell_pulse_sec = Column(Integer, default=3)  # مدة نبضة الجرس بالثواني
    is_pinned_state = Column(Boolean, default=False)  # تثبيت الحالة الحالية ومنع التغيير
    alert_watt_threshold = Column(Float, nullable=True)  # تنبيه عند تجاوز واط معين بدون فصل
    auto_off_delay_sec = Column(Integer, nullable=True)  # إطفاء تلقائي بعد مدة تشغيل بالثواني

    # حماية الراوتر والأجهزة الحيوية من الإطفاء بالخطأ
    is_router = Column(Boolean, default=False)
    is_locked = Column(Boolean, default=False)


    # توأم الحالة (Device Shadow)
    reported_state = Column(Boolean, default=False)
    desired_state = Column(Boolean, default=False)
    power_on_behavior = Column(String(10), default="LAST")  # ON / OFF / LAST

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
    min_watt_cutoff = Column(Float, nullable=True)  # حد فصل الشواحن واكتمال الشحن
    cutoff_delay_sec = Column(Integer, default=600)  # مهلة فحص الخمول (ثوانٍ)
    compressor_protect = Column(Boolean, default=False)
    compressor_delay_sec = Column(Integer, default=180)  # مهلة أمان مواتير التبريد (ثوانٍ)
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
    hold_state = Column(Boolean, default=False)  # تثبيت حالة الجدولة ومنع التغيير اليدوي أثناءها
    is_active = Column(Boolean, default=True)
    next_run_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=utc_now)

    socket = relationship("Socket", back_populates="schedules")


class Scene(Base):
    """جدول المشاهد المجمعة مع التأخير المتتابع لمنع الشرارة"""
    __tablename__ = "scenes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    scene_name = Column(String(100), nullable=False)
    icon = Column(String(50), default="sparkles")
    stagger_delay_ms = Column(Integer, default=1500)
    actions_json = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utc_now)

    user = relationship("User", back_populates="scenes")


class SharedAccess(Base):
    """جدول مشاركة المشترك مع أفراد العائلة بأكواد دعوة وصلاحيات محددة"""
    __tablename__ = "shared_access"

    id = Column(Integer, primary_key=True, index=True)
    strip_id = Column(Integer, ForeignKey("strips.id", ondelete="CASCADE"), nullable=False)
    shared_with_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    member_name = Column(String(100), default="فرد عائلة")
    permission_level = Column(String(20), default="FULL")  # FULL / PARTIAL / VIEW
    allowed_sockets = Column(String(50), default="1,2,3,4")  # comma-separated e.g. "1" or "1,2"
    is_active = Column(Boolean, default=True)
    invite_code = Column(String(32), unique=True, index=True, nullable=True)
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
    """الصندوق الأسود لتوثيق كافة الأوامر وأسباب الفصل ومحاولات قفل الأطفال"""
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    strip_id = Column(Integer, ForeignKey("strips.id", ondelete="CASCADE"), nullable=False)
    socket_index = Column(Integer, nullable=True)
    action = Column(String(30), nullable=False)
    triggered_by = Column(String(30), nullable=False)
    actor_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    reason_details = Column(String(255), nullable=True)
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
    """جدول أكواد التحقق السحابية لاستعادة كلمة المرور (Email OTP)"""
    __tablename__ = "password_resets"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), index=True, nullable=False)
    otp_code = Column(String(10), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    is_used = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), default=utc_now)


class OutletRunSession(Base):
    """جدول سجل جلسات التشغيل التفصيلي (Run log — last 30 days) لكل مخرج"""
    __tablename__ = "outlet_run_sessions"

    id = Column(Integer, primary_key=True, index=True)
    strip_id = Column(Integer, ForeignKey("strips.id", ondelete="CASCADE"), index=True, nullable=False)
    socket_id = Column(Integer, ForeignKey("sockets.id", ondelete="CASCADE"), index=True, nullable=False)
    socket_index = Column(Integer, nullable=False)
    socket_name = Column(String(50), default="مقبس")
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
    """جدول مقترحات المستخدمين وملاحظات الدعم الفني"""
    __tablename__ = "feedback_suggestions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    email = Column(String(255), nullable=True)
    message = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utc_now)
