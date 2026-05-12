
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workmanager/workmanager.dart';
import 'package:ecomerk2/data/services/navigation_mode_service.dart';
import 'package:ecomerk2/data/services/security_manager.dart';
import 'package:ecomerk2/data/services/storage_service.dart';
import 'package:ecomerk2/data/services/notification_service.dart';
import 'package:ecomerk2/core/workers/price_check_worker.dart';
import 'routes/app_routes.dart';
import 'themes/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NavigationModeService.instance.load();

  // Inicializar notificaciones locales
  await NotificationService.instance.init();

  // Registrar tarea periódica de verificación de precios en background
  await Workmanager().initialize(priceCheckCallback, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    kPriceCheckTask,
    kPriceCheckTask,
    frequency: kPriceCheckFrequency,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'EcoMerk2',
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

    // Obtener nuevas llaves RSA/AES al iniciar
    await SecurityManager().refreshKeys();

    final storage = StorageService();

    // Intentar auto-login con credenciales en SharedPreferences (legacy)
    // Si el token seguro está vigente, ir directo al home
    final tokenVigente = await storage.tokenEstaVigente();
    final token = await storage.obtenerToken();
    final userId = await storage.obtenerUserId();

    if (tokenVigente && token != null && userId != null) {
      if (mounted) context.go('/home');
      return;
    }

    // Sin sesión válida: ir al login
    if (mounted) context.go('/login');
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
            Text(
              'EcoMerk2',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F6E56),
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF1D9E75)),
          ],
        ),
      ),
    );
  }
}
