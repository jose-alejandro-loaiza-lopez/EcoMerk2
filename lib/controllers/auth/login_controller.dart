import 'package:flutter/material.dart';
import '../../data/models/auth_result.dart';
import '../../data/services/login_service.dart';

/// Controlador del flujo de inicio de sesión.
///
/// Expone los [TextEditingController] para los campos del formulario y
/// orquesta el proceso de autenticación mediante [LoginService],
/// devolviendo un [Stream] con los estados [AuthResult].
class LoginController {
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();

  final _service = LoginService();

  /// Inicia el proceso de autenticación y retorna un [Stream<AuthResult>]
  /// con los estados: [AuthLoading] → [AuthSuccess] | [AuthError].
  ///
  /// La vista debe escuchar este stream para reaccionar a cada estado.
  Stream<AuthResult> login() {
    return _service.login(
      emailController.text.trim(),
      passwordController.text,
    );
  }

  void dispose() {
    emailController.dispose();
    passwordController.dispose();
  }
}