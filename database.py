from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, declarative_base
from config import settings

connect_args = {"check_same_thread": False, "timeout": 20.0} if settings.DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(
    settings.DATABASE_URL,
    connect_args=connect_args,
    pool_pre_ping=True,
)

if settings.DATABASE_URL.startswith("sqlite"):
    @event.listens_for(engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode=WAL;")
        cursor.execute("PRAGMA synchronous=NORMAL;")
        cursor.execute("PRAGMA foreign_keys=ON;")
        cursor.close()

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def run_db_migrations(target_engine=None):
    """التحقق من حقول وقواعد البيانات وإجراء التحديثات التلقائية بدون مساس بالبيانات الحالية"""
    from sqlalchemy import text
    eng = target_engine or engine
    with eng.connect() as conn:
        try:
            res = conn.execute(text("PRAGMA table_info(users);")).fetchall()
            cols = [r[1] for r in res]
            if "plan_name" not in cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN plan_name VARCHAR(20) DEFAULT 'FREE';"))
                conn.execute(text("UPDATE users SET plan_name = 'ADMIN' WHERE role = 'ADMIN';"))
                conn.commit()
                print("[DB Migration] ✅ Added 'plan_name' column to 'users' table")
            if "language" not in cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN language VARCHAR(5) DEFAULT 'ar';"))
                conn.commit()
                print("[DB Migration] ✅ Added 'language' column to 'users' table")
        except Exception as e:
            print(f"[DB Migration] ⚠️ Migration notice (users.plan_name): {e}")

        try:
            Base.metadata.create_all(bind=eng)
            print("[DB Migration] ✅ Tables checked and synced with Base.metadata")
        except Exception as e:
            print(f"[DB Migration] ⚠️ Error syncing tables: {e}")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()