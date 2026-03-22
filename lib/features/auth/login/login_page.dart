import 'package:flutter/material.dart';
import 'login_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _controller = LoginController();
  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    if (_controller.emailController.text.isEmpty ||
        _controller.passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos.')),
      );
      return;
    }

    setState(() => _loading = true);
    final result = await _controller.login();
    setState(() => _loading = false);

    if (result['exito']) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['mensaje']),
          backgroundColor: Colors.red,
        ),
      );
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
              const SizedBox(height: 60),              Center(
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
                  const Text('Ahorra inteligente cada semana',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 40),
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
                    const Text('Iniciar sesión',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      )),
                    const SizedBox(height: 20),
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D9E75),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _loading
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Text('Ingresar',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              )),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, '/register'),
                        child: RichText(
                          text: const TextSpan(
                            text: '¿No tienes cuenta? ',
                            style: TextStyle(color: Colors.grey),
                            children: [
                              TextSpan(
                                text: 'Regístrate aquí',
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