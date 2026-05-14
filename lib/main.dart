import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const OrderMeApp());
}

class OrderMeApp extends StatelessWidget {
  const OrderMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'W4CASH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3A6FFF)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
