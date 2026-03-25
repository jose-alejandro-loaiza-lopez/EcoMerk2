import 'package:flutter/material.dart';
import 'package:ecomerk2/data/services/user_api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _nombre = '';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    // Verificar si el token sigue vigente antes de hacer la petición
    final vigente = await ApiService.tokenEstaVigente();
    if (!vigente) {
      _redirigirLogin();
      return;
    }

    final id = await ApiService.obtenerUserId();
    if (id == null) {
      _redirigirLogin();
      return;
    }

    final usuario = await ApiService.obtenerUsuario(id);

    if (usuario == null) {
      if (mounted) setState(() { _nombre = 'Usuario'; _cargando = false; });
      return;
    }

    // Si el servidor responde 401/403, sesión expirada
    if (usuario['_tokenExpirado'] == true) {
      _redirigirLogin(mensaje: 'Tu sesión expiró. Inicia sesión nuevamente.');
      return;
    }

    if (mounted) {
      setState(() {
        _nombre = usuario['nombre'] ?? 'Usuario';
        _cargando = false;
      });
    }
  }

  void _redirigirLogin({String? mensaje}) async {
    await ApiService.borrarToken();
    if (!mounted) return;
    if (mensaje != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.orange),
      );
    }
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _cerrarSesion() async {
    await ApiService.borrarToken();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('EcoMerca2',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1D9E75),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1D9E75)))
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🛒', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text(
                    '¡Bienvenido, $_nombre!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C2C2A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ahorra inteligente cada semana',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 280,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/favorites'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D9E75),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.list_alt, color: Colors.white),
                      label: const Text('Ver mi lista de compras',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}