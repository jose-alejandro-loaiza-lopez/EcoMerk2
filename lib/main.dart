import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ecomerk2/data/services/user_api_service.dart';
import 'routes/app_routes.dart';
import 'themes/app_theme.dart';void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'EcoMerk',
      theme: AppTheme.defaultTheme,
      routerConfig: AppRoutes.router,
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});
  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final token = await ApiService.obtenerToken();
    final userId = await ApiService.obtenerUserId();

    if (token != null && userId != null) {
      if (mounted) context.go('/home');
    } else {
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🛒', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('EcoMerca2',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F6E56),
              )),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF1D9E75)),
          ],
        ),
      ),
    );
  }
}