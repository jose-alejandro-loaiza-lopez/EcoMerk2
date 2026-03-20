import 'package:flutter/material.dart';
import 'register_service.dart';

class RegisterController {
  final nombreController       = TextEditingController();
  final emailController        = TextEditingController();
  final passwordController     = TextEditingController();
  final fechaNacController     = TextEditingController();
  final RegisterService _service = RegisterService();

  Future<Map<String, dynamic>> registrar() async {
    return await _service.registrar(
      nombre: nombreController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text,
      fechaNacimiento: fechaNacController.text.trim(),
    );
  }

  void dispose() {
    nombreController.dispose();
    emailController.dispose();
    passwordController.dispose();
    fechaNacController.dispose();
  }
}