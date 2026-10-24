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
    """ترقية الجداول تلقائياً وتشفير أي بيانات قديمة غير مشفرة بـ AES-256-GCM + Blind Indexes"""
    from sqlalchemy import text
    from crypto_utils import encrypt_str, decrypt_str, compute_blind_index, CIPHERTEXT_PREFIX

    eng = target_engine or engine
    with eng.connect() as conn:
        try:
            Base.metadata.create_all(bind=eng)
        except Exception as e:
            print(f"[DB Migration] ⚠️ Error creating base tables: {e}")

        def _ensure_column(table: str, col: str, col_def: str):
            try:
                rows = conn.execute(text(f"PRAGMA table_info({table});")).fetchall()
                existing = {r[1] for r in rows}
                if existing and col not in existing:
                    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {col} {col_def};"))
                    conn.commit()
            except Exception as err:
                print(f"[DB Migration] ⚠️ Column check notice ({table}.{col}): {err}")

        _ensure_column("users", "plan_name", "VARCHAR(20) DEFAULT 'FREE'")
        _ensure_column("users", "language", "VARCHAR(5) DEFAULT 'ar'")
        _ensure_column("users", "email_blind_index", "VARCHAR(64)")
        _ensure_column("users", "google_blind_index", "VARCHAR(64)")
        _ensure_column("users", "webhook_blind_index", "VARCHAR(64)")
        _ensure_column("strips", "mac_blind_index", "VARCHAR(64)")
        _ensure_column("shared_access", "invite_blind_index", "VARCHAR(64)")
        _ensure_column("password_resets", "email_blind_index", "VARCHAR(64)")

        # إنشاء الفهارس الفريدة للبصمات العمياء
        for idx_sql in [
            "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email_blind_index ON users (email_blind_index);",
            "CREATE UNIQUE INDEX IF NOT EXISTS ix_strips_mac_blind_index ON strips (mac_blind_index);",
            "CREATE UNIQUE INDEX IF NOT EXISTS ix_shared_access_invite_blind_index ON shared_access (invite_blind_index);",
            "CREATE INDEX IF NOT EXISTS ix_password_resets_email_blind_index ON password_resets (email_blind_index);",
        ]:
            try:
                conn.execute(text(idx_sql))
                conn.commit()
            except Exception:
                pass

        # تشفير أي صفوف قديمة غير مشفرة تلقائياً (At-Rest Encryption Upgrade)
        try:
            u_rows = conn.execute(
                text("SELECT id, email, full_name, google_uid, telegram_chat_id, notif_prefs_json, webhook_token, email_blind_index FROM users;")
            ).fetchall()
            for r in u_rows:
                uid, em, fn, guid, tg, npj, wh, eb = r
                plain_em = decrypt_str(em) if em else ""
                new_eb = compute_blind_index("email", plain_em) if plain_em else eb
                needs_enc = (
                    (em and not str(em).startswith(CIPHERTEXT_PREFIX))
                    or (fn and not str(fn).startswith(CIPHERTEXT_PREFIX))
                    or (eb != new_eb)
                )
                if needs_enc:
                    conn.execute(
                        text(
                            "UPDATE users SET email=:em, email_blind_index=:eb, full_name=:fn, "
                            "google_uid=:guid, google_blind_index=:gb, telegram_chat_id=:tg, "
                            "notif_prefs_json=:npj, webhook_token=:wh, webhook_blind_index=:wb WHERE id=:id"
                        ),
                        {
                            "id": uid,
                            "em": encrypt_str(plain_em.lower()) if plain_em else em,
                            "eb": new_eb,
                            "fn": encrypt_str(decrypt_str(fn)) if fn else fn,
                            "guid": encrypt_str(decrypt_str(guid)) if guid else guid,
                            "gb": compute_blind_index("google", decrypt_str(guid)) if guid else None,
                            "tg": encrypt_str(decrypt_str(tg)) if tg else tg,
                            "npj": encrypt_str(decrypt_str(npj)) if npj else npj,
                            "wh": encrypt_str(decrypt_str(wh)) if wh else wh,
                            "wb": compute_blind_index("webhook", decrypt_str(wh)) if wh else None,
                        },
                    )
            conn.commit()

            s_rows = conn.execute(
                text("SELECT id, mac_address, strip_name, room_category, ip_address, mac_blind_index FROM strips;")
            ).fetchall()
            for r in s_rows:
                sid, mac, sname, rcat, ip, mb = r
                plain_mac = decrypt_str(mac) if mac else ""
                new_mb = compute_blind_index("mac", plain_mac) if plain_mac else mb
                if (mac and not str(mac).startswith(CIPHERTEXT_PREFIX)) or (mb != new_mb):
                    conn.execute(
                        text(
                            "UPDATE strips SET mac_address=:mac, mac_blind_index=:mb, "
                            "strip_name=:sn, room_category=:rc, ip_address=:ip WHERE id=:id"
                        ),
                        {
                            "id": sid,
                            "mac": encrypt_str(plain_mac.upper()) if plain_mac else mac,
                            "mb": new_mb,
                            "sn": encrypt_str(decrypt_str(sname)) if sname else sname,
                            "rc": encrypt_str(decrypt_str(rcat)) if rcat else rcat,
                            "ip": encrypt_str(decrypt_str(ip)) if ip else ip,
                        },
                    )
            conn.commit()
        except Exception as err:
            print(f"[DB Migration] ⚠️ Encryption upgrade notice: {err}")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
