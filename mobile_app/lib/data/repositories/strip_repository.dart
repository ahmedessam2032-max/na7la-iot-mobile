import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/storage/secure_storage.dart';
import '../models/user_model.dart';
import '../models/strip_model.dart';

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
      body: jsonEncode({'state': state}),
    );
    return response.statusCode == 200;
  }

  Future<bool> lockSocket(String mac, int socketIndex, bool isLocked) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/strips/$mac/sockets/$socketIndex/lock'),
      headers: headers,
      body: jsonEncode({'is_locked': isLocked}),
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
