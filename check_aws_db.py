import sqlite3

conn = sqlite3.connect('/home/ubuntu/na7la-iot/data/na7la_iot.db')
cursor = conn.cursor()

print("--- STRIPS ---")
for s in cursor.execute('SELECT id, mac_address, strip_name, is_online, ip_address, current_voltage, child_lock FROM strips').fetchall():
    print(s)

print("\n--- SOCKETS ---")
for sock in cursor.execute('SELECT socket_index, name, reported_state, current_watt, is_router, is_locked FROM sockets ORDER BY socket_index').fetchall():
    print(sock)

print("\n--- RECENT SCHEDULES ---")
for sch in cursor.execute('SELECT id, socket_id, schedule_type, cycle_on_sec, cycle_off_sec, target_state, is_active FROM schedules').fetchall():
    print(sch)
