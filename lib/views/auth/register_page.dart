import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth/register_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _controller = RegisterController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _acceptedLegalTerms = false;
  bool _showLegalTermsError = false;

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

    if (!_acceptedLegalTerms) {
      setState(() => _showLegalTermsError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes aceptar los términos y la política de datos para crear tu cuenta.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final result = await _controller.registrar();
    setState(() => _loading = false);

    if (result['exito']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada exitosamente.'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/login');
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

  void _mostrarDocumentoLegal(String titulo, String contenido) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(
          child: Text(
            contenido,
            style: const TextStyle(height: 1.35),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarTerminos() {
    _mostrarDocumentoLegal(
      'Términos y condiciones',
      'Al crear una cuenta en Ecomerk2 aceptas usar la plataforma de forma '
          'responsable, suministrar información veraz y proteger tus '
          'credenciales de acceso. Ecomerk2 puede actualizar sus servicios, '
          'precios, disponibilidad de productos y funcionalidades para mejorar '
          'la experiencia del usuario.',
    );
  }

  void _mostrarPoliticaDatos() {
    _mostrarDocumentoLegal(
      'Política de manejo de datos',
      'Ecomerk2 utiliza tus datos personales para crear y administrar tu '
      'cuenta, autenticar tu acceso, personalizar tu experiencia y '
      'gestionar funcionalidades como favoritos, alertas y perfil. Tus '
          'datos se tratan bajo medidas de seguridad y no se solicitan más '
          'datos de los necesarios para operar el servicio.',
    );
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
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      size: 48,
                      color: Color(0xFF0F6E56),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ecomerk2',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F6E56),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Crea tu cuenta gratis',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Crear cuenta',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Nombre completo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controller.nombreController,
                      decoration: InputDecoration(
                        hintText: 'Tu nombre',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Correo electrónico',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controller.emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'tucorreo@gmail.com',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Contraseña',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controller.passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: '********',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fecha de nacimiento',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _controller.fechaNacController,
                      readOnly: true,
                      onTap: _seleccionarFecha,
                      decoration: InputDecoration(
                        hintText: 'Selecciona tu fecha',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                        suffixIcon: const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF1D9E75),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _showLegalTermsError
                              ? Colors.red
                              : Colors.black12,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _acceptedLegalTerms,
                              activeColor: const Color(0xFF1D9E75),
                              onChanged: (value) {
                                setState(() {
                                  _acceptedLegalTerms = value ?? false;
                                  if (_acceptedLegalTerms) {
                                    _showLegalTermsError = false;
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'Acepto los ',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    InkWell(
                                      onTap: _mostrarTerminos,
                                      child: const Text(
                                        'términos y condiciones',
                                        style: TextStyle(
                                          color: Color(0xFF1D9E75),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      ' y la ',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    InkWell(
                                      onTap: _mostrarPoliticaDatos,
                                      child: const Text(
                                        'política de manejo de datos',
                                        style: TextStyle(
                                          color: Color(0xFF1D9E75),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      '.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showLegalTermsError) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Debes aceptar para continuar con el registro.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D9E75),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Crear cuenta',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: () => context.pop(),
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
