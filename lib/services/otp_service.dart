import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'app_settings_service.dart';

class OtpService {
  OtpService._();
  static final OtpService instance = OtpService._();

  static const _phoneKey = 'registered_phone';

  Future<void> savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phone);
  }

  Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  Future<bool> sendOtp(String phone) async {
    final res = await http.post(
      Uri.parse('${AppSettingsService.baseUrl}/auth/otp/send'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone}),
    );
    return res.statusCode == 200;
  }

  Future<User?> verifyOtp(String phone, String otp) async {
    final res = await http.post(
      Uri.parse('${AppSettingsService.baseUrl}/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone, 'otp': otp}),
    );
    if (res.statusCode != 200) return null;
    return User.fromJson(json.decode(res.body) as Map<String, dynamic>);
  }

}
