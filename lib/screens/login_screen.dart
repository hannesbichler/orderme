import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/otp_service.dart';
import '../services/product_catalog_service.dart';
import '../utils/string_utils.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'package:nfc_manager/nfc_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  List<User> _users = [];
  bool _loadingUsers = true;
  String? _userFetchError;

  @override
  void initState() {
    super.initState();
    //_initializeNFC();
    _loadUsers();
  }

  bool get _supportsNfcPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _initializeNFC() async {
    if (!_supportsNfcPlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC is not supported on this platform.')),
      );
      return;
    }

    try {
      final isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable || !mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC is not available on this device.')),
        );
        return;
      }

      NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          // Process tag data.
        },
        onError: (error) async {
          if (!mounted) {
            return;
          }

          setState(() {
            _userFetchError = 'Couldn\'t read tag. Try again.';
          });
        },
      );
    } on MissingPluginException {
      // NFC plugin is not registered for this runtime.
      if (!mounted) {
        return;
      }

      setState(() {
        _userFetchError = 'NFC plugin is not available on this platform.';
      });
    } on PlatformException {
      if (!mounted) {
        return;
      }

      setState(() {
        _userFetchError = 'NFC is unavailable on this device.';
      });
    }
  }

  @override
  void dispose() {
    if (_supportsNfcPlatform) {
      NfcManager.instance.stopSession();
    }
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _userFetchError = null;
    });

    try {
      final users = await _authService.fetchUsers();
      setState(() {
        _users = users;
        _loadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _userFetchError = 'Could not load users: $e';
        _loadingUsers = false;
      });
    }
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );

    if (!mounted || changed != true) {
      return;
    }

    AuthService.invalidateCache();
    ProductCatalogService.instance.invalidateCache();
    await _loadUsers();
  }

  void _loginAs(User user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(user: user),
      ),
    );
  }

  Future<void> _loginWithPhone() async {
    final phoneController = TextEditingController();
    final otpController = TextEditingController();

    // Step 1 — enter phone number
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Anmeldung per Telefon'),
        content: TextField(
          controller: phoneController,
          autofocus: true,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(
            labelText: 'Telefonnummer',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(phoneController.text.trim()),
            child: const Text('Code senden'),
          ),
        ],
      ),
    );

    phoneController.dispose();
    if (!mounted || phone == null || phone.isEmpty) return;

    // Send OTP
    bool sent = false;
    try {
      sent = await OtpService.instance.sendOtp(phone);
    } catch (_) {}

    if (!mounted) return;
    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Nummer gefunden. Bitte zuerst Nummer registrieren.')),
      );
      return;
    }

    // Step 2 — enter OTP
    final otp = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Code eingeben'),
        content: TextField(
          controller: otpController,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: '6-stelliger Code',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(otpController.text.trim()),
            child: const Text('Bestätigen'),
          ),
        ],
      ),
    );

    otpController.dispose();
    if (!mounted || otp == null || otp.isEmpty) return;

    User? user;
    try {
      user = await OtpService.instance.verifyOtp(phone, otp);
    } catch (_) {}

    if (!mounted) return;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ungültiger Code.')),
      );
      return;
    }

    _loginAs(user);
  }

  Future<void> _handleUserTap(User user) async {
    if (user.password.trim().isEmpty) {
      await _offerPhoneRegistration(user);
      _loginAs(user);
      return;
    }

    final enteredPassword = await _showPasswordDialog(user);
    if (!mounted || enteredPassword == null) return;
    String passwd = sha1FromString(enteredPassword);
    if (passwd == user.password) {
      await _offerPhoneRegistration(user);
      _loginAs(user);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid password.')),
    );
  }

  Future<void> _offerPhoneRegistration(User user) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (!mounted) return;

    final register = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Telefonnummer hinterlegen?'),
        content: const Text(
            'Möchtest du deine Telefonnummer hinterlegen, um dich künftig per SMS-Code anzumelden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nein'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ja'),
          ),
        ],
      ),
    );

    if (register != true || !mounted) return;

    final phoneController = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Telefonnummer'),
        content: TextField(
          controller: phoneController,
          autofocus: true,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(
            labelText: 'Telefonnummer',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(phoneController.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    phoneController.dispose();
    if (!mounted || phone == null || phone.isEmpty) return;

    try {
      await OtpService.instance.registerPhone(user.id, phone);
    } catch (_) {}
  }

  Future<String?> _showPasswordDialog(User user) async {
    final controller = TextEditingController();
    var obscureText = true;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('Login as ${user.name}'),
              content: TextField(
                controller: controller,
                autofocus: true,
                obscureText: obscureText,
                onSubmitted: (value) {
                  Navigator.of(dialogContext).pop(value.trim());
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setDialogState(() {
                        obscureText = !obscureText;
                      });
                    },
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(controller.text.trim());
                  },
                  child: const Text('Login'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo / Title
              const Icon(Icons.lock_outline_rounded,
                  size: 72, color: Color(0xFF3A6FFF)),
              const SizedBox(height: 12),
              const Text(
                'W4CASH',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a user to continue',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Settings'),
                ),
              ),
              const SizedBox(height: 8),

              // User selection card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Users',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap a user to open the app. Users with a password will be prompted.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _loginWithPhone,
                              icon: const Icon(Icons.phone_iphone),
                              label: const Text('Mit Telefonnummer anmelden'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF3A6FFF),
                                side: const BorderSide(color: Color(0xFF3A6FFF)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                        ],
                        if (_loadingUsers)
                          const Center(child: CircularProgressIndicator())
                        else if (_userFetchError != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _userFetchError!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _loadUsers,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3A6FFF),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ),
                            ],
                          )
                        else if (_users.isEmpty)
                          const Text(
                            'No users available.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          )
                        else
                          ..._users.map(
                            (user) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleUserTap(user),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1A237E),
                                    elevation: 1,
                                    alignment: Alignment.centerLeft,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(
                                        color: Color(0xFFBBCCFF),
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.person_outline,
                                    color: Color(0xFF3A6FFF),
                                  ),
                                  label: Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
