import os

class Settings:
    PROJECT_NAME: str = "Na7la IoT"
    VERSION: str = "1.0.0"

    # مفتاح التوقيع المشفر للجلسات والتوكنات
    SECRET_KEY: str = os.getenv("SECRET_KEY", "na7la_iot_super_secret_master_key_2026")

    # إعدادات قاعدة البيانات (SQLite محلياً أو PostgreSQL على AWS)
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./na7la_iot.db")

    # إعدادات بروتوكول الهاردوير MTTL-W01 (Stock 1.0.66)
    TCP_DEVICE_PORT: int = int(os.getenv("TCP_DEVICE_PORT", 10086))
    SETUP_AP_IP: str = "192.168.1.1"
    SETUP_AP_PORT: int = 30300

    # عنوان السيرفر العام (اختياري للاستخدام خلف دومين أو نفق)
    SERVER_PUBLIC_URL: str = os.getenv("SERVER_PUBLIC_URL", "")

    # إعدادات تسجيل الدخول بحساب Google (OAuth Client ID)
    GOOGLE_CLIENT_ID: str = os.getenv("GOOGLE_CLIENT_ID", "")

    # التوقيتات ومعايرة الحساسات
    POLL_INTERVAL_SEC: float = 5.0
    DIAG_EVERY_N_POLLS: int = 3
    RELAY_SETTLE_DELAY_SEC: float = 0.3
    STAGGER_DEFAULT_SEC: float = 0.15
    CURRENT_NOISE_OFFSET_AMP: float = 0.019  # طرح شوشرة الأمبير لكل مخرج

    # الحدود القصوى للطوارئ الفورية (Short-Circuit Safety)
    EMERGENCY_MAX_WATT: float = 3300.0
    EMERGENCY_MAX_AMP: float = 17.5

    # مدراء النظام وقوائم الصلاحيات والكوتا
    SUPERADMIN_EMAIL: str = os.getenv("SUPERADMIN_EMAIL", "ahmedessam2032@gmail.com")
    ADMIN_EMAILS: list[str] = [
        e.strip().lower() for e in os.getenv("ADMIN_EMAILS", "ahmedessam2032@gmail.com,ahmed@na7la.local").split(",") if e.strip()
    ]
    DEFAULT_USER_MAX_STRIPS: int = int(os.getenv("DEFAULT_USER_MAX_STRIPS", 1))

    # إعدادات خادم البريد الإلكتروني السحابي (AWS SES / SMTP)
    SMTP_HOST: str = os.getenv("SMTP_HOST", "")
    SMTP_PORT: int = int(os.getenv("SMTP_PORT", 587))
    SMTP_USER: str = os.getenv("SMTP_USER", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    SMTP_FROM_EMAIL: str = os.getenv("SMTP_FROM_EMAIL", "noreply@na7la-iot.com")
    SMTP_FROM_NAME: str = os.getenv("SMTP_FROM_NAME", "Na7la IoT Cloud")

settings = Settings()