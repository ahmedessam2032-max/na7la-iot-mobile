import 'package:flutter/material.dart';
import '../storage/secure_storage.dart';
import '../../data/repositories/strip_repository.dart';

class AppLocaleController extends ChangeNotifier {
  static final AppLocaleController instance = AppLocaleController._internal();
  AppLocaleController._internal();

  String _currentLang = 'ar';
  String get currentLang => _currentLang;
  bool get isArabic => _currentLang == 'ar';
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
      'tab_billing': 'الفاتورة',
      'tab_protection': 'الحماية',
      'tab_family': 'العائلة',
      'online': 'متصل',
      'offline': 'أوفلاين',
      'add_strip': 'إضافة',
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
      'app_version': 'Na7la IoT v1.3.3',
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
      'tab_billing': 'Billing',
      'tab_protection': 'Guard',
      'tab_family': 'Family',
      'online': 'Online',
      'offline': 'Offline',
      'add_strip': 'Add',
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
      'app_version': 'Na7la IoT v1.3.3',
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
