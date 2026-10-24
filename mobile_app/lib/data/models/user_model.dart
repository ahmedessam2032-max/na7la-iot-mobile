class UserModel {
  final int id;
  final String email;
  final String? fullName;
  final String role; // ADMIN / USER
  final int maxStrips;
  final bool hasPin;
  final double electricityRateEgp;
  final String tariffMode; // egyptian_tiers | flat
  final Map<String, dynamic> notifPrefs;

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    this.maxStrips = 1,
    this.hasPin = false,
    this.electricityRateEgp = 1.45,
    this.tariffMode = 'egyptian_tiers',
    this.notifPrefs = const {},
  });

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
  int get stripQuota => maxStrips;
  int get maxStripsAllowed => maxStrips;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> prefs = {};
    if (json['notif_prefs'] is Map) {
      prefs = Map<String, dynamic>.from(json['notif_prefs']);
    }
    return UserModel(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      fullName: json['full_name'],
      role: json['role'] ?? 'USER',
      maxStrips: json['strip_quota'] ?? json['max_strips'] ?? 1,
      hasPin: json['has_pin'] ?? false,
      electricityRateEgp: (json['electricity_rate_egp'] as num?)?.toDouble() ?? 1.45,
      tariffMode: json['tariff_mode'] ?? 'egyptian_tiers',
      notifPrefs: prefs,
    );
  }
}
