import 'package:flutter/material.dart';
import '../storage/secure_storage.dart';
import '../../data/repositories/strip_repository.dart';

class AppLocaleController extends ChangeNotifier {
  static final AppLocaleController instance = AppLocaleController._internal();
  AppLocaleController._internal();

  String _currentLang = 'ar';
  String get currentLang => _currentLang;
  bool get isArabic => _currentLang == 'ar';
  bool get isEnglish => _currentLang == 'en';
  TextDirection get textDirection => isArabic ? TextDirection.rtl : TextDirection.ltr;
  Locale get locale => isArabic ? const Locale('ar', 'EG') : const Locale('en', 'US');

  Future<void> init() async {
    final saved = await SecureStorageService.getLanguage();
    if (saved != null && (saved == 'ar' || saved == 'en')) {
      _currentLang = saved;
      notifyListeners();
    }
  }

  Future<void> toggleLanguage() async {
    _currentLang = _currentLang == 'ar' ? 'en' : 'ar';
    await SecureStorageService.setLanguage(_currentLang);
    notifyListeners();

    // Sync to backend asynchronously
    try {
      StripRepository().updateLanguage(_currentLang);
    } catch (_) {}
  }

  Future<void> setLanguage(String lang) async {
    if (lang != 'ar' && lang != 'en') return;
    _currentLang = lang;
    await SecureStorageService.setLanguage(_currentLang);
    notifyListeners();

    try {
      StripRepository().updateLanguage(_currentLang);
    } catch (_) {}
  }

  String tr(String key) {
    return AppTranslations.get(key, _currentLang);
  }
}

class AppTranslations {
  static final Map<String, Map<String, String>> _values = {
    'ar': {
      'app_title': 'نحلة IoT',
      'brand_sub': 'منظومة التحكم الذكي بالطاقة وحماية الأجهزة',
      'quick_switch_target': 'English',
      'tab_login': 'دخول',
      'tab_register': 'حساب جديد',
      'tab_invite': 'كود عائلي 🔑',
      'lbl_email': 'البريد الإلكتروني',
      'hint_email': 'user@example.com',
      'lbl_password': 'كلمة المرور',
      'hint_password': '••••••••',
      'forgot_pass_link': 'نسيت كلمة المرور؟',
      'btn_login': 'تسجيل الدخول',
      'lbl_name': 'الاسم بالكامل',
      'placeholder_name': 'مثال: أحمد عصام',
      'lbl_confirm_pass': 'تأكيد كلمة المرور',
      'btn_register': 'إنشاء الحساب وبدء الاستخدام 🚀',
      'btn_invite_login': 'دخول فوري للمشترك 🚀',
      'invite_hint': 'أدخل كود الدعوة العائلي المكون من 6 أرقام:',
      'pass_guidelines': '🛡️ إرشادات كلمة المرور الآمنة: 8 خانات على الأقل • تحتوي على حروف وأرقام معاً.',
      
      // Forgot Password Modal
      'forgot_modal_title': 'استعادة كلمة المرور',
      'forgot_step1_desc': 'أدخل بريدك الإلكتروني المسجل وسيقوم خادم Na7la IoT بإرسال كود تحقق سري (OTP) مكون من 6 أرقام لتأكيد هويتك.',
      'btn_send_otp': 'إرسال كود التحقق ✉️',
      'forgot_step2_desc': 'تم إرسال كود تحقق سري (OTP) إلى:',
      'lbl_otp_code': 'كود التحقق (6 أرقام)',
      'resend_after': 'إعادة الإرسال بعد:',
      'resend_code_link': 'إعادة إرسال الكود',
      'btn_verify_otp': 'تأكيد كود التحقق',
      'forgot_step3_desc': 'تم تأكيد هويتك بنجاح ✅. يرجى تعيين كلمة المرور الجديدة وتأكيدها:',
      'lbl_new_pass': 'كلمة المرور الجديدة',
      'lbl_confirm_new_pass': 'تأكيد كلمة المرور الجديدة',
      'btn_save_pass_login': 'حفظ كلمة المرور وتسجيل الدخول',
      'otp_hint_sec': '🛡️ 8 خانات على الأقل • مزيج من الحروف والأرقام.',
      
      // Dashboard & Tabs
      'tab_home': 'الخلية',
      'tab_my_strips': 'مشتركاتي',
      'tab_schedules': 'الجدولة',
      'tab_favorites': 'المفضلة',
      'tab_settings': 'الإعدادات',
      'tab_account': 'حسابي',
      'mode_compact': 'العرض المدمج 2x2',
      'mode_detailed': 'العرض التفصيلي الكامل',
      'current_consumption': 'الحمل الحالي',
      'load_distribution': 'توزيع الأحمال اللحظي',
      'tab_billing': 'الفاتورة',
      'tab_protection': 'الحماية',
      'tab_family': 'العائلة',
      'online': 'متصل',
      'offline': 'أوفلاين',
      'add_strip': 'إضافة مشترك',
      'admin_badge': 'الأدمن 👑',
      'smart_all_off': 'إيقاف الكل الذكي',
      'turn_all_on': 'تشغيل الكل',
      'total_power': 'القدرة الإجمالية',
      'voltage': 'جهد الكهرباء',
      'today_bill': 'فاتورة اليوم',
      'watts': 'واط',
      'volts': 'فولت',
      'egp': 'ج.م',
      'amps': 'أمبير',
      
      // Digital Twin Card
      'twin_title': 'التوأم الرقمي الحي ⚡ (MTTL-W01)',
      'twin_interactive': 'تفاعلي مباشر 👆',
      'twin_on': 'يعمل',
      'twin_off': 'مطفأ',
      'twin_connected': 'متصل',
      'twin_tap_hint': '👆 انقر للتبديل',

      // 3-Dots Options Menu
      'strip_options_title': 'خيارات المشترك',
      'menu_rename': 'إعادة تسمية المشترك والمكان',
      'menu_schedules': 'جدولة ومؤقتات المخارج',
      'menu_analytics': 'إحصائيات الطاقة والتحليلات',
      'menu_logs': 'سجل النشاط اللحظي',
      'menu_diagnostics': 'حالة المشترك وفحص الهاردوير (Diagnostics)',
      'menu_child_lock': 'قفل الأطفال (Child Lock)',
      'menu_voltage_guard': 'حماية الجهد الكهربائي (Voltage Guard)',
      'menu_family': 'مشاركة المشترك مع العائلة والضيوف',
      'menu_pin_lock': 'قفل التحكم بكلمة سر / PIN',
      'menu_connection_mode': 'نمط الاتصال بالمشترك (سحابي / محلي بدون إنترنت)',
      'menu_delete_strip': 'حذف المشترك وإلغاء الاقتران 🗑️',

      // Settings Tab
      'settings_sec_appearance': 'المظهر واللغة',
      'settings_app_language': 'لغة التطبيق',
      'settings_sec_security': 'الأمان والحماية المتقدمة',
      'settings_voltage_protection': 'حماية الجهد والفولت الكهربائي',
      'settings_master_pin': 'رمز PIN الماستر',
      'settings_pin_active': 'مفعّل 🔐',
      'settings_pin_inactive': 'غير مفعّل 🔓',
      'settings_biometric_lock': 'قفل التطبيق بالبصمة',
      'settings_biometric_sub': 'طلب البصمة أو رمز الجهاز عند فتح التطبيق',
      'settings_tariff_price': 'سعر الكيلوواط (تسعيرة الفاتورة)',
      'settings_sec_management': 'إدارة المشتركات والعائلة',
      'settings_family_sharing': 'مشاركة المشترك العائلية',
      'settings_family_sub': 'إدارة صلاحيات أفراد المنزل والأجهزة المسموحة',
      'settings_admin_portal': 'بوابة إدارة المنصة (Admin Console)',
      'settings_admin_sub': 'إدارة المستخدمين والمشتركات والكوتا',
      'settings_sec_system': 'النظام والمعلومات',
      'settings_about_title': 'حول تطبيق نحلة IoT',
      'settings_developer_title': 'المطور والجهة المنفذة',
      'settings_developer_val': 'م/ أحمد عصام (IoT Architect)',
      'settings_support_title': 'الدعم الفني المباشر',
      'settings_support_sub': 'تواصل عبر WhatsApp أو LinkedIn',
      'settings_strip_model': 'طراز الهاردوير',
      'settings_mac_address': 'عنوان MAC',
      'settings_ip_address': 'عنوان IP المحلي',
      'settings_fw_version': 'إصدار الفيرموير',
      'settings_cloud_server': 'خادم السحابة',
      'settings_logout_btn': 'تسجيل الخروج من الحساب',

      // Energy Analytics Screen
      'analytics_title': 'إحصائيات الطاقة والتحليلات',
      'analytics_tier_current': 'الشريحة الثالثة حالياً',
      'analytics_calc_title': 'حاسبة فاتورة الكهرباء المصرية (المشترك)',
      'analytics_cumulative': 'الاستهلاك التراكمي:',
      'analytics_tier_remaining': 'المتبقي للشريحة التالية: 58 kWh',
      'analytics_weekly_chart': '📊 منحنى استهلاك الطاقة الأسبوعي',
      'analytics_weekly_badge': 'أسبوعي',
      'analytics_peak_hours': '⏰ ساعات الذروة المسجلة: 7:00 م - 11:00 م',
      'analytics_leaderboard': '🔌 ترتيب استهلاك المخارج (من يسحب أكثر؟)',
      'analytics_export_btn': 'تصدير تقرير الاستهلاك الكامل (.xlsx)',

      // Sockets and Hardware
      'router_badge': 'راوتر 🛡️',
      'socket_prefix': 'مقبس',
      'outlet_router': 'راوتر الإنترنت',
      
      // Supplementary & Profile
      'profile_title': 'الملف الشخصي والإعدادات',
      'quota_status': 'كوتة المشتركات المسموحة:',
      'pricing_plans': 'الأسعار والاشتراك 💳',
      'tech_support': 'الدعم الفني المباشر 💬',
      'about_app': 'حول التطبيق والمطور 🐝',
      'app_lang': 'لغة التطبيق (العربية / English)',
      'dark_mode': 'الوضع الليلي (تيتانيوم)',
      'light_mode': 'الوضع النهاري',
      'logout': 'تسجيل الخروج',
      
      // Quota Upgrade Modal
      'quota_reached_title': 'وصلت للحد الأقصى للمشتركات 🛡️',
      'quota_reached_desc': 'خطتك الحالية (الخطة المجانية) تسمح بربط مشترك واحد فقط.\nلربط حتى 15 مشتركاً مع تحكم غير محدود، يرجى ترقية حسابك إلى خطة برو الاحترافية.',
      'btn_upgrade_whatsapp': 'ترقية الحساب عبر الواتساب 🚀',
      'btn_close': 'إغلاق',
      
      // About & Credits
      'developer_credit': 'المطور: أحمد عصام (Ahmed Essam)',
      'app_version': 'Na7la IoT v2.0.0',
    },
    'en': {
      'app_title': 'Na7la IoT',
      'brand_sub': 'Smart Energy Management & Hardware Protection',
      'quick_switch_target': 'العربية',
      'tab_login': 'Sign In',
      'tab_register': 'New Account',
      'tab_invite': 'Family Code 🔑',
      'lbl_email': 'Email Address',
      'hint_email': 'user@example.com',
      'lbl_password': 'Password',
      'hint_password': '••••••••',
      'forgot_pass_link': 'Forgot Password?',
      'btn_login': 'Sign In',
      'lbl_name': 'Full Name',
      'placeholder_name': 'e.g. Ahmed Essam',
      'lbl_confirm_pass': 'Confirm Password',
      'btn_register': 'Create Account & Get Started 🚀',
      'btn_invite_login': 'Instant Access with Code 🚀',
      'invite_hint': 'Enter the 6-digit family invite code:',
      'pass_guidelines': '🛡️ Secure Password Guidelines: At least 8 characters • Must contain letters & numbers.',
      
      // Forgot Password Modal
      'forgot_modal_title': 'Reset Password',
      'forgot_step1_desc': 'Enter your registered email and Na7la IoT server will send a 6-digit secret OTP to verify your identity.',
      'btn_send_otp': 'Send Verification Code ✉️',
      'forgot_step2_desc': 'A secret verification OTP has been sent to:',
      'lbl_otp_code': 'Verification Code (6 digits)',
      'resend_after': 'Resend in:',
      'resend_code_link': 'Resend Code',
      'btn_verify_otp': 'Verify OTP Code',
      'forgot_step3_desc': 'Identity verified successfully ✅. Please set and confirm your new password:',
      'lbl_new_pass': 'New Password',
      'lbl_confirm_new_pass': 'Confirm New Password',
      'btn_save_pass_login': 'Save Password & Sign In',
      'otp_hint_sec': '🛡️ At least 8 characters • mix of letters & numbers.',
      
      // Dashboard & Tabs
      'tab_home': 'Strip',
      'tab_my_strips': 'My Strips',
      'tab_schedules': 'Schedules',
      'tab_favorites': 'Favorites',
      'tab_settings': 'Settings',
      'tab_account': 'Account',
      'mode_compact': '2x2 Compact View',
      'mode_detailed': 'Full Detailed View',
      'current_consumption': 'Current Load',
      'load_distribution': 'Real-time Load Distribution',
      'tab_billing': 'Billing',
      'tab_protection': 'Guard',
      'tab_family': 'Family',
      'online': 'Online',
      'offline': 'Offline',
      'add_strip': 'Add Strip',
      'admin_badge': 'Admin 👑',
      'smart_all_off': 'Smart All OFF',
      'turn_all_on': 'Turn All ON',
      'total_power': 'Total Load',
      'voltage': 'AC Voltage',
      'today_bill': 'Today Cost',
      'watts': 'Watts',
      'volts': 'Volts',
      'egp': 'EGP',
      'amps': 'Amps',

      // Digital Twin Card
      'twin_title': 'Live Digital Twin ⚡ (MTTL-W01)',
      'twin_interactive': 'Live Interactive 👆',
      'twin_on': 'ON',
      'twin_off': 'OFF',
      'twin_connected': 'Online',
      'twin_tap_hint': '👆 Tap to toggle',

      // 3-Dots Options Menu
      'strip_options_title': 'Strip Options',
      'menu_rename': 'Rename Strip & Room',
      'menu_schedules': 'Schedules & Timers',
      'menu_analytics': 'Energy & Analytics',
      'menu_logs': 'Live Activity Log',
      'menu_diagnostics': 'Hardware Health & Diagnostics',
      'menu_child_lock': 'Child Lock',
      'menu_voltage_guard': 'Voltage Guard',
      'menu_family': 'Family & Guest Sharing',
      'menu_pin_lock': 'Security PIN Lock',
      'menu_connection_mode': 'Connection Target (Cloud / LAN)',
      'menu_delete_strip': 'Unpair & Delete Strip 🗑️',

      // Settings Tab
      'settings_sec_appearance': 'Appearance & Language',
      'settings_app_language': 'App Language',
      'settings_sec_security': 'Security & Advanced Guard',
      'settings_voltage_protection': 'Voltage & Surge Protection',
      'settings_master_pin': 'Master PIN Code',
      'settings_pin_active': 'Active 🔐',
      'settings_pin_inactive': 'Disabled 🔓',
      'settings_biometric_lock': 'Biometric App Lock',
      'settings_biometric_sub': 'Require Face ID / Fingerprint on launch',
      'settings_tariff_price': 'Electricity Tariff (kWh Price)',
      'settings_sec_management': 'Strip Management & Family',
      'settings_family_sharing': 'Family Sharing',
      'settings_family_sub': 'Manage family members & allowed outlets',
      'settings_admin_portal': 'Admin Console & Fleet Management',
      'settings_admin_sub': 'Manage platform users, strips & quotas',
      'settings_sec_system': 'System & About',
      'settings_about_title': 'About Na7la IoT',
      'settings_developer_title': 'Developer & Engineering',
      'settings_developer_val': 'Eng. Ahmed Essam (IoT Architect)',
      'settings_support_title': 'Technical Support',
      'settings_support_sub': 'Connect via WhatsApp or LinkedIn',
      'settings_strip_model': 'Hardware Model',
      'settings_mac_address': 'MAC Address',
      'settings_ip_address': 'Local IP Address',
      'settings_fw_version': 'Firmware Version',
      'settings_cloud_server': 'Cloud Server',
      'settings_logout_btn': 'Sign Out from Account',

      // Energy Analytics Screen
      'analytics_title': 'Energy & Analytics',
      'analytics_tier_current': 'Tier 3 (Active)',
      'analytics_calc_title': 'Egyptian Electricity Calculator',
      'analytics_cumulative': 'Cumulative Energy:',
      'analytics_tier_remaining': 'Remaining to next tier: 58 kWh',
      'analytics_weekly_chart': '📊 Weekly Energy Consumption',
      'analytics_weekly_badge': 'Weekly',
      'analytics_peak_hours': '⏰ Peak hours: 7:00 PM - 11:00 PM',
      'analytics_leaderboard': '🔌 Outlets Consumption Ranking',
      'analytics_export_btn': 'Export Full Consumption Report (.xlsx)',

      // Sockets and Hardware
      'router_badge': 'Router 🛡️',
      'socket_prefix': 'Outlet',
      'outlet_router': 'Internet Router',
      
      // Supplementary & Profile
      'profile_title': 'Profile & Settings',
      'quota_status': 'Strip Quota Limit:',
      'pricing_plans': 'Pricing & Plans 💳',
      'tech_support': 'Technical Support 💬',
      'about_app': 'About Na7la IoT 🐝',
      'app_lang': 'App Language (English / العربية)',
      'dark_mode': 'Dark Mode (Titanium)',
      'light_mode': 'Light Mode',
      'logout': 'Sign Out',
      
      // Quota Upgrade Modal
      'quota_reached_title': 'Strip Quota Limit Reached 🛡️',
      'quota_reached_desc': 'Your current plan (Free Tier) allows pairing 1 smart strip only.\nTo connect up to 15 strips with unlimited schedules, please upgrade to Pro Plan.',
      'btn_upgrade_whatsapp': 'Upgrade Account via WhatsApp 🚀',
      'btn_close': 'Close',
      
      // About & Credits
      'developer_credit': 'Developer: Ahmed Essam',
      'app_version': 'Na7la IoT v2.0.0',
    }
  };

  static String get(String key, String lang) {
    if (_values.containsKey(lang) && _values[lang]!.containsKey(key)) {
      return _values[lang]![key]!;
    }
    if (_values['ar']!.containsKey(key)) {
      return _values['ar']![key]!;
    }
    return key;
  }
}

/// Global bilingual helper that automatically returns Arabic or English
/// according to [AppLocaleController.instance.isArabic].
String trBi(String ar, String en) {
  return AppLocaleController.instance.isArabic ? ar : en;
}

/// Automatically translates default Arabic/English outlet names when switching languages,
/// while preserving custom user-defined outlet names.
String trOutletName(String rawName, [int? outletIndex]) {
  final isAr = AppLocaleController.instance.isArabic;
  final trimmed = rawName.trim();
  if (trimmed.isEmpty) {
    final idx = outletIndex ?? 1;
    return isAr ? 'مقبس $idx' : 'Outlet $idx';
  }
  const routerAr = {'راوتر الإنترنت', 'الراوتر', 'راوتر'};
  const routerEn = {'Internet Router', 'Router'};
  if (routerAr.contains(trimmed) || routerEn.contains(trimmed)) {
    return isAr ? 'راوتر الإنترنت' : 'Internet Router';
  }
  final arMatch = RegExp(r'^(?:مقبس|المخرج|مخرج|فيشة|الفيشة)\s*(\d+)$').firstMatch(trimmed);
  if (arMatch != null) {
    final numStr = arMatch.group(1)!;
    return isAr ? 'مقبس $numStr' : 'Outlet $numStr';
  }
  final enMatch = RegExp(r'^(?:Outlet|Socket)\s*(\d+)$', caseSensitive: false).firstMatch(trimmed);
  if (enMatch != null) {
    final numStr = enMatch.group(1)!;
    return isAr ? 'مقبس $numStr' : 'Outlet $numStr';
  }
  return rawName;
}

/// Automatically translates default room names when switching languages.
String trRoomName(String rawRoom) {
  final isAr = AppLocaleController.instance.isArabic;
  final trimmed = rawRoom.trim();
  const mapArToEn = {
    'غرفة المعيشة': 'Living Room',
    'غرفة النوم': 'Bedroom',
    'المكتب': 'Office',
    'المطبخ': 'Kitchen',
    'غرفة الأطفال': 'Kids Room',
    'الصالة': 'Hall',
    'عام': 'General',
  };
  if (!isAr && mapArToEn.containsKey(trimmed)) {
    return mapArToEn[trimmed]!;
  }
  if (isAr) {
    for (final entry in mapArToEn.entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
        return entry.key;
      }
    }
  }
  return rawRoom;
}
