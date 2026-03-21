import 'package:flutter/material.dart';
import 'login_service.dart';

class LoginController {
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  final LoginService _service = LoginService();

  Future<Map<String, dynamic>> login() async {
    return await _service.login(
      emailController.text.trim(),
      passwordController.text,
    );
  }

  void dispose() {
    emailController.dispose();
    passwordController.dispose();
  }
}