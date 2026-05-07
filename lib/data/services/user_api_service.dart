import 'package:http/http.dart' as http;
import 'dart:convert';
import 'security_manager.dart';
import 'storage_service.dart';

/// Servicio de acceso a la API de usuarios.
///
/// El almacenamiento de sesión está completamente delegado a [StorageService]:
/// - Token JWT → [FlutterSecureStorage] (cifrado, solo desde StorageService).
/// - Nombre, email, userId → [SharedPreferences] (desde StorageService).
class ApiService {
  static const String baseUrl =
      'https://usuarios-bd-production.up.railway.app/api/v1';

  static final _storage = StorageService();

  static http.Client get _client =>
      SecurityManager().client ?? http.Client();

  // ══════════════════════════════════════════════════════════════════════════
  // MÉTODOS DE STORAGE — delegan a StorageService
  // ══════════════════════════════════════════════════════════════════════════

  /// Recupera el JWT desde almacenamiento seguro.
  static Future<String?> obtenerToken() => _storage.obtenerToken();

  /// Verifica si el token almacenado está vigente (< 23h).
  static Future<bool> tokenEstaVigente() => _storage.tokenEstaVigente();

  /// Elimina todos los datos de sesión de ambos storages.
  static Future<void> borrarToken() => _storage.limpiarSesion();

  /// Recupera el ID de usuario desde SharedPreferences.
  static Future<int?> obtenerUserId() => _storage.obtenerUserId();

  // ══════════════════════════════════════════════════════════════════════════
  // LOGIN (retrocompatibilidad con AuthCheck en main.dart)
  // ══════════════════════════════════════════════════════════════════════════

  /// Realiza login y persiste la sesión a través de [StorageService].
  ///
  /// Para el flujo con estados Loading/Success/Error, usar [LoginService].
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
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final token      = body['token']   as String? ?? '';
        final userId     = body['id']      as int?    ?? 0;
        final usuarioObj = body['usuario'] as Map<String, dynamic>?;
        final nombre     = usuarioObj?['nombre'] as String?
                        ?? body['nombre']         as String?
                        ?? '';
        final emailResp  = usuarioObj?['email']  as String?
                        ?? body['email']          as String?
                        ?? email;

        await _storage.guardarSesion(
          token:     token,
          nombre:    nombre,
          email:     emailResp,
          usuarioId: userId,
        );
        return {'exito': true};
      } else {
        return {'exito': false, 'mensaje': 'Correo o contraseña incorrectos'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'No se pudo conectar al servidor'};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REGISTRO
  // ══════════════════════════════════════════════════════════════════════════

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

  // ══════════════════════════════════════════════════════════════════════════
  // OBTENER USUARIO (con detección de token expirado)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> obtenerUsuario(int id) async {
    try {
      final token = await obtenerToken();
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

  // ══════════════════════════════════════════════════════════════════════════
  // ACTUALIZAR FAVORITOS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<bool> actualizarLista(int id, List<dynamic> lista) async {
    try {
      final token = await obtenerToken();
      final response = await _client.patch(
        Uri.parse('$baseUrl/usuarios/$id/favoritos'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(lista),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BÚSQUEDA DE PRODUCTOS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<dynamic>?> buscarProductos(String query) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/productos?search=$query'),
      headers: {'Authorization': 'Bearer ${await obtenerToken()}'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }
}
