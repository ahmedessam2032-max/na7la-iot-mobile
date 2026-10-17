class ApiConstants {
  // Production AWS Cloud Endpoints
  static const String serverHost = '13.61.25.9';
  static const int httpPort = 80;
  static const int wsPort = 80;
  static const int tcpHardwarePort = 10086;

  static const String baseUrl = 'http://$serverHost/api/v1';
  static const String wsBaseUrl = 'ws://$serverHost/ws/strips';

  // Hardware SoftAP Defaults
  static const String defaultStripIp = '192.168.1.1';
  static const int defaultStripPort = 30300;
  static const String softApPrefix = 'TONLY_TAP_';

  // Egyptian Electricity Tiers (EGP per kWh)
  static const List<Map<String, dynamic>> egyptianTiers = [
    {'tier': 1, 'min': 0, 'max': 50, 'rate': 0.68, 'label': 'الشريحة الأولى (0-50 kWh)'},
    {'tier': 2, 'min': 51, 'max': 100, 'rate': 0.78, 'label': 'الشريحة الثانية (51-100 kWh)'},
    {'tier': 3, 'min': 101, 'max': 200, 'rate': 0.95, 'label': 'الشريحة الثالثة (101-200 kWh)'},
    {'tier': 4, 'min': 201, 'max': 350, 'rate': 1.55, 'label': 'الشريحة الرابعة (201-350 kWh)'},
    {'tier': 5, 'min': 351, 'max': 650, 'rate': 1.95, 'label': 'الشريحة الخامسة (351-650 kWh)'},
    {'tier': 6, 'min': 651, 'max': 1000, 'rate': 2.10, 'label': 'الشريحة السادسة (651-1000 kWh)'},
    {'tier': 7, 'min': 1001, 'max': 999999, 'rate': 2.23, 'label': 'الشريحة السابعة (>1000 kWh)'},
  ];
}
