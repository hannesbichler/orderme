import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  AppSettingsService._();

  static const String _hostKey = 'webservice_host';
  static const String _portKey = 'webservice_port';
 // static const String _defaultHost = '127.0.0.1';
  static const String _defaultHost = '217.154.223.125';
  static const int _defaultPort = 3000;

  static String _host = _defaultHost;
  static int _port = _defaultPort;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHost = prefs.getString(_hostKey)?.trim();
    final savedPort = prefs.getInt(_portKey);

    if (savedHost != null && savedHost.isNotEmpty) {
      _host = savedHost;
    }

    if (savedPort != null && savedPort > 0 && savedPort <= 65535) {
      _port = savedPort;
    }
  }

  static String get host => _host;
  static int get port => _port;

  static String get baseUrl => 'http://$_host:$_port';

  static Future<void> setHostAndPort({
    required String host,
    required int port,
  }) async {
    final normalized = host.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Host/IP cannot be empty.');
    }
    if (port <= 0 || port > 65535) {
      throw ArgumentError('Port must be between 1 and 65535.');
    }

    _host = normalized;
    _port = port;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, _host);
    await prefs.setInt(_portKey, _port);
  }
}