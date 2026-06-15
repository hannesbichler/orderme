import 'package:flutter/material.dart';
import 'services/product_catalog_service.dart';
import 'services/app_settings_service.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettingsService.init();
  try {
    await ProductCatalogService.instance.preloadProducts();
    await ProductCatalogService.instance.preloadCategories();
  } catch (_) {
    // Product cache can be loaded lazily by screens if startup preload fails.
  }

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
