import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const EcoMerca2App());
}

class EcoMerca2App extends StatelessWidget {
  const EcoMerca2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoMerca2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D9E75),
        ),
        useMaterial3: true,
      ),
      // Rutas de la app
      routes: {
        '/login':    (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
      },
      // Decide qué pantalla mostrar según si hay sesión activa
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {

          // Cargando...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1D9E75),
                ),
              ),
            );
          }

          // Si hay usuario logueado → Dashboard (por ahora pantalla temporal)
          if (snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('EcoMerca2'),
                backgroundColor: const Color(0xFF1D9E75),
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                  ),
                ],
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🛒', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text(
                      '¡Bienvenido, ${snapshot.data?.displayName ?? 'Usuario'}!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.data?.email ?? '',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Si no hay sesión → pantalla de Login
          return const LoginScreen();
        },
      ),
    );
  }
}