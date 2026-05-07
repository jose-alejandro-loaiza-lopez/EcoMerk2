import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/auth_result.dart';
import 'storage_service.dart';
import 'security_manager.dart';
import 'user_api_service.dart';

/// Servicio de autenticación JWT.
///
/// Gestiona el ciclo completo de inicio de sesión, emitiendo los estados
/// definidos en [AuthResult]: [AuthLoading] → [AuthSuccess] | [AuthError].
///
/// En caso de éxito, delega el almacenamiento al [StorageService]:
/// - `access_token` → [FlutterSecureStorage] (cifrado).
/// - `nombre`, `email`, `usuarioId` → [SharedPreferences].
class LoginService {
  final _storage = StorageService();

  static http.Client get _client =>
      SecurityManager().client ?? http.Client();

  /// Ejecuta el flujo de autenticación y emite los estados del proceso.
  ///
  /// Uso:
  /// ```dart
  /// await for (final estado in loginService.login(email, password)) {
  ///   switch (estado) {
  ///     case AuthLoading() => mostrarSpinner();
  ///     case AuthSuccess() => irAHome();
  ///     case AuthError()   => mostrarError(estado.mensaje);
  ///   }
  /// }
  /// ```
  Stream<AuthResult> login(String email, String password) async* {
    // 1. Emitir estado de carga
    yield AuthLoading();

    try {
      final response = await _client.post(
        Uri.parse('${ApiService.baseUrl}/usuarios/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;

        final token      = body['token']  as String? ?? '';
        final usuarioId  = body['id']     as int?    ?? 0;
        // El backend puede devolver nombre y email dentro del objeto usuario
        final usuarioObj = body['usuario'] as Map<String, dynamic>?;
        final nombre     = usuarioObj?['nombre'] as String?
                        ?? body['nombre']         as String?
                        ?? '';
        final emailResp  = usuarioObj?['email']  as String?
                        ?? body['email']          as String?
                        ?? email; // fallback al email que ingresó el usuario

        if (token.isEmpty) {
          yield AuthError(mensaje: 'El servidor no devolvió un token válido.');
          return;
        }

        // 2. Persistir sesión de forma segmentada
        await _storage.guardarSesion(
          token:     token,
          nombre:    nombre,
          email:     emailResp,
          usuarioId: usuarioId,
        );

        debugPrint('LoginService: sesión guardada. userId=$usuarioId');

        // 3. Emitir éxito con los datos del usuario
        yield AuthSuccess(
          token:     token,
          nombre:    nombre,
          email:     emailResp,
          usuarioId: usuarioId,
        );
      } else {
        // Intentar obtener mensaje del backend
        String mensaje = 'Correo o contraseña incorrectos';
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          mensaje = body['mensaje'] ?? body['message'] ?? mensaje;
        } catch (_) {}

        yield AuthError(mensaje: mensaje);
      }
    } catch (e) {
      debugPrint('LoginService error: $e');
      yield AuthError(mensaje: 'No se pudo conectar al servidor. Verifica tu conexión.');
    }
  }
}