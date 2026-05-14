import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final AuthService _authService = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Hint users loaded from the web service
  List<User> _users = [];
  bool _loadingUsers = true;
  String? _userFetchError;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );

      if (!mounted) return;

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(user: user),
          ),
        );
      } else {
        setState(() => _errorMessage = 'Invalid username or password.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
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
                'Sign in to continue',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Login card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Username
                        TextFormField(
                          controller: _usernameCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please enter your username'
                                  : null,
                        ),
                        const SizedBox(height: 16),

                        // Password (= email for demo users)
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password (email)',
                            prefixIcon:
                                const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _obscurePassword =
                                      !_obscurePassword),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please enter your password'
                                  : null,
                        ),
                        const SizedBox(height: 8),

                        if (_errorMessage != null)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 8),

                        // Login button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF3A6FFF),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8)),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Available users hint panel
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available accounts (from web service)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Username  /  Password (email)',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                      const Divider(),
                      if (_loadingUsers)
                        const Center(child: CircularProgressIndicator())
                      else if (_userFetchError != null)
                        Text(_userFetchError!,
                            style: const TextStyle(color: Colors.red))
                      else
                        ..._users.map(
                          (u) => InkWell(
                            onTap: () {
                              _usernameCtrl.text = u.name;
                              _passwordCtrl.text = "";//u.email;
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.person,
                                      size: 14,
                                      color: Color(0xFF3A6FFF)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${u.name}  ·  "",//{u.email}',
                                      style: const TextStyle(
                                          fontSize: 12),
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
