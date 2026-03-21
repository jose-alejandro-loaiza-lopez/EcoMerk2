import 'package:flutter/material.dart';
import 'register_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _controller = RegisterController();
  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _handleRegister() async {
    if (_controller.nombreController.text.isEmpty ||
        _controller.emailController.text.isEmpty ||
        _controller.passwordController.text.isEmpty ||
        _controller.fechaNacController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos.')),
      );
      return;
    }

    setState(() => _loading = true);
    final result = await _controller.registrar();
    setState(() => _loading = false);

    if (result['exito']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada exitosamente!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['mensaje']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (fecha != null) {
      _controller.fechaNacController.text =
          '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Logo
              Center(
                child: Column(children: [
                  const Text('🛒', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  const Text('EcoMerca2',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F6E56),
                    )),
                  const SizedBox(height: 4),
                  const Text('Crea tu cuenta gratis',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 40),
              // Tarjeta
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 10)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Crear cuenta',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      )),
                    const SizedBox(height: 20),
                    // Nombre
                    const Text('Nombre completo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controller.nombreController,
                      decoration: InputDecoration(
                        hintText: 'Tu nombre',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Email
                    const Text('Correo electrónico',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controller.emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'tucorreo@gmail.com',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Contraseña
                    const Text('Contraseña',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controller.passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Fecha de nacimiento
                    const Text('Fecha de nacimiento',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controller.fechaNacController,
                      readOnly: true,
                      onTap: _seleccionarFecha,
                      decoration: InputDecoration(
                        hintText: 'Selecciona tu fecha',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                        suffixIcon: const Icon(Icons.calendar_today,
                            color: Color(0xFF1D9E75)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Botón
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D9E75),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _loading
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Text('Crear cuenta',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              )),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Link login
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: RichText(
                          text: const TextSpan(
                            text: '¿Ya tienes cuenta? ',
                            style: TextStyle(color: Colors.grey),
                            children: [
                              TextSpan(
                                text: 'Inicia sesión',
                                style: TextStyle(
                                  color: Color(0xFF1D9E75),
                                  fontWeight: FontWeight.w600,
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}