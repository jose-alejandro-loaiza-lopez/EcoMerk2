import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/services/storage_service.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    Navigator.pop(context); // Cerrar drawer
    await StorageService().limpiarSesion();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1D9E75)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  'EcoMerk2',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Buscador y Comparador',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            onTap: () {
              Navigator.pop(context);
              context.go('/home');
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Buscar Precios'),
            onTap: () {
              Navigator.pop(context);
              context.push('/search');
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Mi lista de compras'),
            onTap: () {
              Navigator.pop(context);
              context.push('/favorites');
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('EcoAssistant'),
            onTap: () {
              Navigator.pop(context);
              context.push('/chat');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Perfil'),
            onTap: () {
              Navigator.pop(context);
              context.go('/profile');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () => _cerrarSesion(context),
          ),
        ],
      ),
    );
  }
}
