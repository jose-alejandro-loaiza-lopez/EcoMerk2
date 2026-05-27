import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ecomerk2/data/services/navigation_mode_service.dart'
    as nav_service;
import 'package:ecomerk2/data/services/user_api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _usuario;
  bool _cargando = true;
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _cargarPerfil();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    final id = await ApiService.obtenerUserId();
    if (id == null) return;
    final usuario = await ApiService.obtenerUsuario(id);
    if (usuario != null && mounted) {
      setState(() {
        _usuario = usuario;
        _nombreController.text = usuario['nombre'] ?? '';
        _emailController.text = usuario['email'] ?? '';
        _cargando = false;
      });
      _animController.forward();
    }
  }

  String _obtenerIniciales() {
    final nombre = _nombreController.text;
    if (nombre.isEmpty) return 'U';
    final partes = nombre.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre[0].toUpperCase();
  }

  Future<void> _cerrarSesion() async {
    await ApiService.borrarToken();
    if (mounted) context.go('/login');
  }

  // ─── EDITAR PERFIL ──────────────────────────────────────────
  Future<void> _mostrarDialogoEditar() async {
    final editNombreCtrl = TextEditingController(text: _nombreController.text);
    final editEmailCtrl = TextEditingController(text: _emailController.text);
    final editPasswordCtrl = TextEditingController();
    String editFechaNacimiento = _usuario?['fechaNacimiento'] ?? '';
    bool obscurePassword = true;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: Color(0xFF1D9E75), size: 22),
              SizedBox(width: 8),
              Text(
                'Editar perfil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditField(
                  editNombreCtrl,
                  'Nombre',
                  Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                _buildEditField(editEmailCtrl, 'Correo', Icons.email_outlined),
                const SizedBox(height: 12),
                TextField(
                  controller: editPasswordCtrl,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    hintText: 'Mínimo 8 caracteres',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF1D9E75),
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: const Color(0xFF1D9E75),
                        size: 20,
                      ),
                      onPressed: () => setDialogState(
                        () => obscurePassword = !obscurePassword,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1D9E75),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  readOnly: true,
                  controller: TextEditingController(text: editFechaNacimiento),
                  onTap: () async {
                    final fecha = await showDatePicker(
                      context: context,
                      initialDate: _parseFecha(editFechaNacimiento),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (fecha != null) {
                      setDialogState(() {
                        editFechaNacimiento =
                            '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    hintText: 'Selecciona tu fecha',
                    prefixIcon: const Icon(
                      Icons.cake_outlined,
                      color: Color(0xFF1D9E75),
                      size: 20,
                    ),
                    suffixIcon: const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF1D9E75),
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1D9E75),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D9E75),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (resultado == true) {
      final id = await ApiService.obtenerUserId();
      if (id == null) return;

      // Validaciones básicas
      if (editNombreCtrl.text.trim().isEmpty ||
          editEmailCtrl.text.trim().isEmpty ||
          editPasswordCtrl.text.isEmpty ||
          editFechaNacimiento.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Todos los campos son obligatorios'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (editPasswordCtrl.text.length < 8) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La contraseña debe tener al menos 8 caracteres'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Actualizando perfil...'),
              ],
            ),
            backgroundColor: Color(0xFF1D9E75),
            duration: Duration(seconds: 5),
          ),
        );
      }

      final res = await ApiService.actualizarPerfil(
        id: id,
        nombre: editNombreCtrl.text.trim(),
        email: editEmailCtrl.text.trim(),
        password: editPasswordCtrl.text,
        fechaNacimiento: editFechaNacimiento.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['mensaje'] ?? 'Operación completada'),
            backgroundColor: res['exito'] == true
                ? const Color(0xFF1D9E75)
                : Colors.red,
          ),
        );

        if (res['exito'] == true) {
          // Recargar datos del perfil
          setState(() => _cargando = true);
          await _cargarPerfil();
        }
      }
    }
  }

  DateTime _parseFecha(String fecha) {
    try {
      final parts = fecha.split('-');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (_) {}
    return DateTime(2000);
  }

  Widget _buildEditField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF1D9E75), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1D9E75), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  // ─── ELIMINAR CUENTA ────────────────────────────────────────
  Future<void> _eliminarCuenta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Eliminar cuenta',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas eliminar tu cuenta?\n\n'
          'Esta acción es irreversible. Se eliminarán todos tus datos, '
          'favoritos y chat.',
          style: TextStyle(color: Color(0xFF555555)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final id = await ApiService.obtenerUserId();
      if (id == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Eliminando cuenta...'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }

      final res = await ApiService.eliminarCuenta(id);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (res['exito'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cuenta eliminada correctamente'),
              backgroundColor: Color(0xFF1D9E75),
            ),
          );
          context.go('/login');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['mensaje'] ?? 'Error al eliminar la cuenta'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usarMenuLateral =
        nav_service.NavigationModeService.instance.isDrawerMode;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/home'),
        ),
        backgroundColor: const Color(0xFF1D9E75),
        title: const Text(
          'Mi Perfil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF9FE1CB)),
            tooltip: 'Editar perfil',
            onPressed: _mostrarDialogoEditar,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF9FE1CB)),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
            )
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Avatar
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1D9E75), Color(0xFF0F6E56)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1D9E75).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _obtenerIniciales(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _nombreController.text,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C2C2A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _emailController.text,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 28),

                    // Info de la cuenta
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE8E8E8),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Información de la cuenta',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C2C2A),
                                ),
                              ),
                              GestureDetector(
                                onTap: _mostrarDialogoEditar,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1D9E75,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        size: 12,
                                        color: Color(0xFF1D9E75),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Editar',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF1D9E75),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            Icons.person_outline_rounded,
                            'Nombre',
                            _nombreController.text,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            Icons.email_outlined,
                            'Correo',
                            _emailController.text,
                          ),
                          if (_usuario?['fechaNacimiento'] != null) ...[
                            const Divider(height: 24),
                            _buildInfoRow(
                              Icons.cake_outlined,
                              'Fecha de nacimiento',
                              _usuario!['fechaNacimiento'],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE8E8E8),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preferencias de navegación',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C2C2A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SwitchListTile(
                            title: const Text(
                              'Cambiar a menú lateral',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF2C2C2A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            value: usarMenuLateral,
                            activeThumbColor: const Color(0xFF1D9E75),
                            onChanged: (value) async {
                              await nav_service.NavigationModeService.instance
                                  .setMode(
                                    value
                                        ? nav_service.NavigationMode.drawer
                                        : nav_service.NavigationMode.bottomNav,
                                  );
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Estadísticas
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE8E8E8),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mi actividad',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C2C2A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  Icons.favorite_rounded,
                                  '${(_usuario?['favoritos'] as List?)?.length ?? 0}',
                                  'Favoritos',
                                  const Color(0xFFFFEBF0),
                                  const Color(0xFFD4537E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cerrar sesión
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cerrarSesion,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          'Cerrar sesión',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Eliminar cuenta
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _eliminarCuenta,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Eliminar mi cuenta',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1D9E75), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2C2C2A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String valor,
    String label,
    Color bg,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}
