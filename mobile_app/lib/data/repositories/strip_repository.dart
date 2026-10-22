import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/storage/secure_storage.dart';
import '../models/user_model.dart';
import '../models/strip_model.dart';
import '../models/schedule_model.dart';

class StripRepository {
  Future<Map<String, String>> _getHeaders() async {
    final token = await SecureStorageService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'X-Na7la-Token': token,
    };
  }

  // --- Auth Endpoints ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && (data['success'] == true || data['ok'] == true)) {
      final token = data['token'];
      await SecureStorageService.saveToken(token);
      await SecureStorageService.saveUserRole(data['user']?['role'] ?? 'USER');
      await SecureStorageService.saveUserEmail(email);
      return {'success': true, 'user': data['user'] != null ? UserModel.fromJson(data['user']) : null};
    }
    return {'success': false, 'message': data['detail'] ?? 'فشل تسجيل الدخول'};
  }

  Future<Map<String, dynamic>> register(String email, String password, String fullName) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && (data['ok'] == true || data['success'] == true)) {
        final token = data['token'];
        if (token != null) {
          await SecureStorageService.saveToken(token);
          await SecureStorageService.saveUserRole(data['role'] ?? data['user']?['role'] ?? 'USER');
          await SecureStorageService.saveUserEmail(email);
        }
        return {
          'success': true,
          'user': data['user'] != null ? UserModel.fromJson(data['user']) : null,
          'data': data,
        };
      }
      return {'success': false, 'message': data['detail'] ?? 'فشل إنشاء الحساب'};
    } catch (e) {
      return {'success': false, 'message': 'تعذر الاتصال بالسيرفر: $e'};
    }
  }

  Future<Map<String, dynamic>> loginInvite(String inviteCode) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/login-invite'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'invite_code': inviteCode}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && (data['success'] == true || data['ok'] == true)) {
      final token = data['token'];
      await SecureStorageService.saveToken(token);
      await SecureStorageService.saveUserRole('GUEST');
      return {'success': true, 'data': data};
    }
    return {'success': false, 'message': data['detail'] ?? 'كود الدعوة غير صالح أو منتهي'};
  }

  Future<void> logout() async {
    try {
      final headers = await _getHeaders();
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/logout'),
        headers: headers,
      );
    } catch (_) {}
    await SecureStorageService.clearSession();
  }

  // --- Password Reset & Language Sync ---

  Future<Map<String, dynamic>> requestForgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['ok'] == true) {
        return {'success': true, 'message': data['message'] ?? 'تم إرسال كود التحقق بنجاح'};
      }
      return {'success': false, 'message': data['detail'] ?? 'تعذر إرسال كود التحقق'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال بالسيرفر: $e'};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['ok'] == true) {
        return {'success': true, 'message': data['message'] ?? 'تم التحقق بنجاح'};
      }
      return {'success': false, 'message': data['detail'] ?? 'كود التحقق غير صحيح أو انتهت صلاحيته'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال بالسيرفر: $e'};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
          'new_password': newPassword.trim(),
          'confirm_password': confirmPassword.trim(),
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['ok'] == true) {
        return {'success': true, 'message': data['message'] ?? 'تم إعادة تعيين كلمة المرور بنجاح'};
      }
      return {'success': false, 'message': data['detail'] ?? 'تعذر إعادة تعيين كلمة المرور'};
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال بالسيرفر: $e'};
    }
  }

  Future<bool> updateLanguage(String lang) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/auth/language'),
        headers: headers,
        body: jsonEncode({'language': lang}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<UserModel?> getAuthStatus() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/auth/status'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['authenticated'] == true && data['user'] != null) {
        return UserModel.fromJson(data['user']);
      }
    }
    return null;
  }

  Future<bool> setPin(String newPin) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/set-pin'),
      headers: headers,
      body: jsonEncode({'new_pin': newPin, 'confirm_pin': newPin}),
    );
    if (response.statusCode == 200) {
      await SecureStorageService.savePin(newPin);
      return true;
    }
    return false;
  }

  // --- Strips & Sockets Endpoints ---

  Future<List<StripModel>> getStrips() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/strips'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final rawList = data['strips'] as List? ?? [];
      return rawList.map((x) => StripModel.fromJson(x)).toList();
    }
    return [];
  }

  Future<bool> switchSocket(String mac, int socketIndex, bool state) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac/sockets/$socketIndex/switch'),
      headers: headers,
      body: jsonEncode({
        'action': state ? 'on' : 'off',
        'state': state,
      }),
    );
    return response.statusCode == 200;
  }

  Future<bool> updateChildLock(String mac, bool enabled) async {
    return updateProtection(mac, {'child_lock': enabled});
  }

  Future<bool> lockSocket(String mac, int socketIndex, bool isLocked, {String? pin}) async {
    final headers = await _getHeaders();
    final Map<String, dynamic> body = {
      'locked': isLocked,
      'is_locked': isLocked,
    };
    if (pin != null && pin.isNotEmpty) {
      body['pin'] = pin;
    }
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac/sockets/$socketIndex/lock'),
      headers: headers,
      body: jsonEncode(body),
    );
    return response.statusCode == 200;
  }

  Future<bool> configSocket(String mac, int socketIndex, Map<String, dynamic> config) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac/sockets/$socketIndex/config'),
      headers: headers,
      body: jsonEncode(config),
    );
    return response.statusCode == 200;
  }

  Future<bool> resetEnergy(String mac, int socketIndex) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac/sockets/$socketIndex/reset-energy'),
      headers: headers,
    );
    return response.statusCode == 200;
  }

  Future<bool> updateProtection(String mac, Map<String, dynamic> protectionSettings) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac/protection'),
      headers: headers,
      body: jsonEncode(protectionSettings),
    );
    return response.statusCode == 200;
  }

  Future<bool> claimStrip(String mac) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac/claim'),
      headers: headers,
    );
    return response.statusCode == 200;
  }

  // --- Schedules & Repeating Cycles Endpoints ---

  Future<List<ScheduleModel>> getSocketSchedules(String mac, int socketIndex) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac/sockets/$socketIndex/schedules'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = data['schedules'] as List? ?? [];
      return list.map((x) => ScheduleModel.fromJson(x)).toList();
    }
    return [];
  }

  Future<bool> createSchedule({
    required String mac,
    required int socketIndex,
    required String scheduleType, // TIMER / CYCLE / CRON / AUTO_OFF
    bool targetState = true,
    int? timerDurationSec,
    int? cycleOnSec,
    int? cycleOffSec,
    String? cronExpression,
    int? autoOffDelaySec,
  }) async {
    final headers = await _getHeaders();
    final Map<String, dynamic> body = {
      'schedule_type': scheduleType,
      'target_state': targetState,
    };
    if (timerDurationSec != null) body['timer_duration_sec'] = timerDurationSec;
    if (cycleOnSec != null) body['cycle_on_sec'] = cycleOnSec;
    if (cycleOffSec != null) body['cycle_off_sec'] = cycleOffSec;
    if (cronExpression != null) body['cron_expression'] = cronExpression;
    if (autoOffDelaySec != null) body['auto_off_delay_sec'] = autoOffDelaySec;

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac/sockets/$socketIndex/schedules'),
      headers: headers,
      body: jsonEncode(body),
    );
    return response.statusCode == 200;
  }

  Future<bool> createCycleSchedule({
    required String mac,
    required int socketIndex,
    required int cycleOnSec,
    required int cycleOffSec,
    bool initialOn = true,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac/sockets/$socketIndex/schedules'),
      headers: headers,
      body: jsonEncode({
        'schedule_type': 'CYCLE',
        'cycle_on_sec': cycleOnSec,
        'cycle_off_sec': cycleOffSec,
        'target_state': initialOn,
      }),
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteSchedule(int scheduleId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/schedules/$scheduleId'),
      headers: headers,
    );
    return response.statusCode == 200;
  }

  Future<bool> toggleSchedule(int scheduleId) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConstants.baseUrl}/schedules/$scheduleId/toggle'),
      headers: headers,
    );
    return response.statusCode == 200;
  }

  // --- Family & Shares Endpoints ---

  Future<List<dynamic>> getShares(String mac) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac/shares'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['shares'] as List? ?? [];
    }
    return [];
  }

  Future<Map<String, dynamic>> createShare(String mac, String memberName, String permissionLevel, String allowedSockets) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac/shares'),
      headers: headers,
      body: jsonEncode({
        'member_name': memberName,
        'permission_level': permissionLevel,
        'allowed_sockets': allowedSockets,
      }),
    );
    return jsonDecode(response.body);
  }

  Future<bool> deleteShare(int shareId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/shares/$shareId'),
      headers: headers,
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteStrip(String mac) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac'),
      headers: headers,
    );
    return response.statusCode == 200;
  }

  Future<bool> updateStripMetadata(String mac, {String? name, String? roomCategory, String? icon}) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac'),
      headers: headers,
      body: jsonEncode({
        if (name != null) 'strip_name': name,
        if (roomCategory != null) 'room_category': roomCategory,
        if (icon != null) 'icon': icon,
      }),
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> registerStrip(String mac, {String? name, String? roomCategory, String? icon}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/strips/register'),
      headers: headers,
      body: jsonEncode({
        'mac': mac,
        if (name != null) 'name': name,
        if (roomCategory != null) 'room_category': roomCategory,
        if (icon != null) 'icon': icon,
      }),
    );
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {'ok': response.statusCode == 200};
    }
  }

  Future<Map<String, dynamic>> getStripStatus(String mac) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/strips/$mac/status'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {'ok': false, 'is_online': false};
  }

  // --- Admin Endpoints ---

  Future<List<dynamic>> getAdminUsers() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/admin/users'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['users'] as List? ?? [];
    }
    return [];
  }

  Future<List<dynamic>> getAdminStrips() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/admin/strips'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['strips'] as List? ?? [];
    }
    return [];
  }

  Future<bool> updateAdminUserQuota(int userId, int newQuota) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConstants.baseUrl}/admin/users/$userId/quota'),
      headers: headers,
      body: jsonEncode({'max_strips': newQuota}),
    );
    return response.statusCode == 200;
  }
}
