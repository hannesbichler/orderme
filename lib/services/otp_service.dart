import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import 'app_settings_service.dart';

class OtpService {
  OtpService._();
  static final OtpService instance = OtpService._();

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

  Future<bool> registerPhone(String personId, String phone) async {
    final res = await http.post(
      Uri.parse('${AppSettingsService.baseUrl}/auth/otp/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'personId': personId, 'phone': phone}),
    );
    return res.statusCode == 200;
  }
}
