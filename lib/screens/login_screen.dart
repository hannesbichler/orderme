import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/product_catalog_service.dart';
import '../utils/string_utils.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

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
    _loadUsers();
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

  Future<void> _handleUserTap(User user) async {
    if (user.password.trim().isEmpty) {
      _loginAs(user);
      return;
    }

    final enteredPassword = await _showPasswordDialog(user);
    if (!mounted || enteredPassword == null) return;
    String passwd = sha1FromString(enteredPassword);
    if (passwd == user.password) {
      _loginAs(user);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid password.')),
    );
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
