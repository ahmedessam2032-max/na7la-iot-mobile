"""
Na7la IoT — Windows AP Setup Tool (أداة إعداد واي فاي المشترك الذكي من اللابتوب)
مستخرجة ومطابقة 100% لبروتوكول تطبيق درويش الأصلي للمشترك الكوري MTTL-W01.
"""

import socket
import sys
import time

AP_IP = "192.168.1.1"
AP_PORT = 30300
DEFAULT_SERVER_IP = "13.61.25.9"  # AWS Cloud Server IP


def main():
    print("=" * 65)
    print(" 🔌 أداة إعداد واي فاي المشترك الذكي — Na7la IoT Setup Tool")
    print(" بروتوكول التشغيل الأصلي لمشترك MTTL-W01 (Darwish Protocol)")
    print("=" * 65)
    print("\nالخطوة 1: اضغط مطولاً على زر المشترك لمدة 10 ثوانٍ حتى تومض لمبة الواي فاي بسرعة.")
    print("الخطوة 2: من قائمة شبكات الواي فاي على اللابتوب، اتصل بشبكة المشترك (مثال: TONLY_TAP_xxxx)")
    print("         (الباسورد الافتراضي للشبكة يبدأ بـ LGU_ متبوعاً بالسيريال)")
    print("-" * 65)

    ssid = input("\n1. اكتب اسم شبكة واي فاي المنزل (2.4 GHz): ").strip()
    if not ssid:
        print("❌ لم يتم إدخال اسم الشبكة!")
        return

    password = input("2. اكتب كلمة مرور واي فاي المنزل: ").strip()

    server_ip = input(f"3. آي بي سيرفر السحابة (افتراضي {DEFAULT_SERVER_IP} اضغط Enter للموافقة): ").strip()
    if not server_ip:
        server_ip = DEFAULT_SERVER_IP

    print(f"\nجاري الاتصال بنقطة وصول المشترك على {AP_IP}:{AP_PORT}...")
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(8.0)
        s.connect((AP_IP, AP_PORT))
        print("✅ تم الاتصال بنجاح بنقطة وصول المشترك الداخلي!")

        # 1. إرسال أمر تعيين السيرفر السحابي (مثل كود درويش بالضبط: up:ip:<server_ip>)
        cmd_ip = f"up:ip:{server_ip}\r\n".encode("utf-8")
        print(f"📡 جاري تعيين سيرفر السحابة: up:ip:{server_ip}")
        s.sendall(cmd_ip)
        time.sleep(0.8)

        # 2. إرسال أمر ربط واي فاي المنزل (مثل كود درويش بالضبط: up:connect:<ssid>:<password>)
        cmd_connect = f"up:connect:{ssid}:{password}\r\n".encode("utf-8")
        print(f"📶 جاري إرسال بيانات الواي فاي: up:connect:{ssid}:******")
        s.sendall(cmd_connect)
        time.sleep(1.0)

        try:
            resp = s.recv(1024).decode("utf-8", "ignore")
            if resp:
                print(f"📩 استجابة المشترك: {resp.strip()}")
        except Exception:
            pass

        s.close()
        print("\n🎉 تم إرسال أوامر الإعداد للمشترك بنجاح 100%!")
        print("💡 الآن: سيعيد المشترك تشغيل الواي فاي، ويتصل براوتر المنزل، ثم يتصل فوراً بسيرفر Na7la IoT.")
        print(f"يمكنك الآن فتح لوحة التحكم: http://{DEFAULT_SERVER_IP}:8080")

    except Exception as err:
        print(f"\n❌ تعذر الاتصال بالمشترك على ({AP_IP}:{AP_PORT})")
        print(f"سبب الخطأ: {err}")
        print("⚠️ تنبيه: تأكد أنك متصل بشبكة المشترك (TONLY_TAP_...) قبل تشغيل هذا السكريبت.")


if __name__ == "__main__":
    main()
