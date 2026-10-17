# Na7la IoT - Smart Strip Mobile Application & Cloud Platform

نظام متكامل لإدارة وتحكم المشترك الذكي (MTTL-W01) والتحكم بالمخارج المستقلة ومراقبة استهلاك الطاقة بالجنيه المصري.

## المكونات
- `mobile_app/`: تطبيق الموبايل الأصلي المبني بإطار عمل Flutter (Android APK).
- `.github/workflows/build_apk.yml`: سير عمل التجميع السحابي التلقائي للـ APK.
- `main.py`: خادم الـ REST API وبث التيليميتري اللحظي عبر WebSockets.
- `tcp_server.py`: خادم الهاردوير لاتصال المشترك السحابي (Tuya Protocol).
