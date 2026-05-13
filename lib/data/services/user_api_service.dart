import 'package:http/http.dart' as http;
import 'dart:convert';
import 'security_manager.dart';
import 'storage_service.dart';
import 'package:ecomerk2/core/constants/env_config.dart';

class ApiService {
  static String get baseUrl => EnvConfig.baseUrl;

  static final StorageService _storage = StorageService.instance;

  static http.Client get _client {
    return SecurityManager().client ?? http.Client();
  }

  // ─── TOKEN ACCESS ────────────────────────────────────────────
  static Future<void> guardarToken(String token) async {
    await _storage.guardarToken(token);
  }

  static Future<String?> obtenerToken() async {
    return await _storage.obtenerToken();
  }

  static Future<bool> tokenEstaVigente() async {
    return await _storage.tokenEstaVigente();
  }

  // ─── REFRESH TOKEN ───────────────────────────────────────────
  static Future<void> guardarRefreshToken(String refreshToken) async {
    await _storage.guardarRefreshToken(refreshToken);
  }

  static Future<String?> obtenerRefreshToken() async {
    return await _storage.obtenerRefreshToken();
  }

  /// Renueva el access token usando el refresh token.
  ///
  /// Según docs.md sección 1 (POST /auth/refresh):
  /// - Envía `{ "refreshToken": "<REFRESH_TOKEN>" }`
  /// - Recibe `{ "token", "refreshToken", "mensaje" }`
  /// - Rotación: el backend invalida el refresh token anterior
  ///   y devuelve uno nuevo — ambos deben actualizarse en el cliente.
  ///
  /// Endpoint público: NO usa el SecureClient cifrado (no envía
  /// Authorization header), solo http.Client directo.
  static Future<bool> renovarToken() async {
    try {
      final refreshToken = await obtenerRefreshToken();
      if (refreshToken == null) return false;

      // POST /auth/refresh es público, NO necesita SecureClient
      final response = await http.Client().post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        // Rotación: guardar AMBOS tokens nuevos
        await guardarToken(body['token']);
        await guardarRefreshToken(body['refreshToken']);
        return true;
      }

      // Si el refresh token está expirado/revocado, limpiar sesión
      if (response.statusCode == 401 ||
          response.statusCode == 500 ||
          response.statusCode == 400) {
        // Token inválido — no borrar sesión aquí para permitir
        // que el fallback de credenciales intente un re-login
        return false;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene un access token válido, renovando si es necesario.
  ///
  /// Flujo:
  /// 1. Si el token está vigente (< 23h) → lo devuelve
  /// 2. Si no → intenta renovar con refreshToken
  /// 3. Si falla → retorna null (el caller debe manejar re-login)
  static Future<String?> obtenerTokenValido() async {
    final vigente = await tokenEstaVigente();
    if (!vigente) {
      final renovado = await renovarToken();
      if (!renovado) return null;
    }
    return await obtenerToken();
  }

  // ─── BORRAR SESIÓN ───────────────────────────────────────────
  static Future<void> borrarToken() async {
    await _storage.borrarSesion();
  }

  // ─── USUARIO ID ──────────────────────────────────────────────
  static Future<void> guardarUserId(int id) async {
    await _storage.guardarUserId(id);
  }

  static Future<int?> obtenerUserId() async {
    return await _storage.obtenerUserId();
  }

  static Future<void> guardarCredenciales(
      String email, String password) async {
    await _storage.guardarCredenciales(email, password);
  }

  static Future<Map<String, String>?> obtenerCredenciales() async {
    return await _storage.obtenerCredenciales();
  }

  // ─── REGISTRO ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> registrar({
    required String nombre,
    required String email,
    required String password,
    required String fechaNacimiento,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/usuarios/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'email': email,
          'password': password,
          'fechaNacimiento': fechaNacimiento,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'exito': true, 'mensaje': 'Cuenta creada exitosamente'};
      } else {
        final body = jsonDecode(response.body);
        return {
          'exito': false,
          'mensaje': body['mensaje'] ?? 'Error al registrarse',
        };
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'No se pudo conectar al servidor'};
    }
  }

  // ─── LOGIN ───────────────────────────────────────────────────
  /// Login del usuario.
  ///
  /// Según docs.md sección 2 (POST /usuarios/login):
  /// - Envía `{ "email", "password" }`
  /// - Recibe `{ "token", "refreshToken", "id", "mensaje" }`
  /// - Almacena access token y refresh token de forma segura
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/usuarios/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        await guardarToken(body['token']);
        await guardarRefreshToken(body['refreshToken']);
        await guardarUserId(body['id']);
        await guardarCredenciales(email, password);
        return {'exito': true};
      } else {
        return {
          'exito': false,
          'mensaje': 'Correo o contraseña incorrectos',
        };
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'No se pudo conectar al servidor'};
    }
  }

  // ─── OBTENER USUARIO ─────────────────────────────────────────
  static Future<Map<String, dynamic>?> obtenerUsuario(int id) async {
    try {
      final token = await obtenerTokenValido();
      if (token == null) return {'_tokenExpirado': true};

      final response = await _client.get(
        Uri.parse('$baseUrl/usuarios/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['usuario'];
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return {'_tokenExpirado': true};
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── FAVORITOS ───────────────────────────────────────────────
  /// Sincroniza la lista de favoritos con el backend.
  ///
  /// Según docs.md: PATCH /usuarios/{id}/favoritos
  /// Body: array de { productId: string, notificaciones: bool }
  static Future<bool> actualizarLista(int id, List<dynamic> lista) async {
    try {
      final token = await obtenerTokenValido();
      if (token == null) return false;

      // Convertir la lista interna al formato que espera el backend
      final listaFormateada = lista.map((item) {
        if (item is Map) {
          return {
            'productId': item['productId'] ?? item['link'] ?? item['nombre'] ?? '',
            'notificaciones': item['notificaciones'] ?? false,
          };
        }
        return {'productId': item.toString(), 'notificaciones': false};
      }).toList();

      final response = await _client.patch(
        Uri.parse('$baseUrl/usuarios/$id/favoritos'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(listaFormateada),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── ACTUALIZAR PERFIL ──────────────────────────────────────
  /// Actualiza el perfil del usuario (owner o admin).
  ///
  /// Según docs.md: PUT /usuarios/{id}
  /// Body: { nombre, email, password, fechaNacimiento }
  static Future<Map<String, dynamic>> actualizarPerfil({
    required int id,
    required String nombre,
    required String email,
    required String password,
    required String fechaNacimiento,
  }) async {
    try {
      final token = await obtenerTokenValido();
      if (token == null) {
        return {'exito': false, 'mensaje': 'Sesión expirada'};
      }

      final response = await _client.put(
        Uri.parse('$baseUrl/usuarios/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nombre': nombre,
          'email': email,
          'password': password,
          'fechaNacimiento': fechaNacimiento,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {
          'exito': true,
          'mensaje': body['mensaje'] ?? 'Perfil actualizado con éxito.',
          'usuario': body['usuario'],
        };
      } else {
        final body = jsonDecode(response.body);
        return {
          'exito': false,
          'mensaje': body['mensaje'] ?? body['error'] ?? 'Error al actualizar',
        };
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'No se pudo conectar al servidor'};
    }
  }

  // ─── ELIMINAR CUENTA ────────────────────────────────────────
  /// Elimina la cuenta del usuario (owner o admin).
  ///
  /// Según docs.md: DELETE /usuarios/{id}
  static Future<Map<String, dynamic>> eliminarCuenta(int id) async {
    try {
      final token = await obtenerTokenValido();
      if (token == null) {
        return {'exito': false, 'mensaje': 'Sesión expirada'};
      }

      final response = await _client.delete(
        Uri.parse('$baseUrl/usuarios/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await borrarToken();
        return {'exito': true, 'mensaje': 'Cuenta eliminada con éxito'};
      } else {
        final body = jsonDecode(response.body);
        return {
          'exito': false,
          'mensaje': body['error'] ?? 'Error al eliminar la cuenta',
        };
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'No se pudo conectar al servidor'};
    }
  }
}