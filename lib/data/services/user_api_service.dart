
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

  /// Recupera el access token JWT desde almacenamiento seguro.
  static Future<String?> obtenerToken() => _storage.obtenerToken();

  /// Recupera el refresh token desde almacenamiento seguro.
  static Future<String?> obtenerRefreshToken() => _storage.obtenerRefreshToken();

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
        final token        = body['token']        as String? ?? '';
        final refreshToken = body['refreshToken']  as String? ?? '';
        final userId       = body['id']            as int?    ?? 0;
        final usuarioObj   = body['usuario'] as Map<String, dynamic>?;
        final nombre       = usuarioObj?['nombre'] as String?
                          ?? body['nombre']         as String?
                          ?? '';
        final emailResp    = usuarioObj?['email']  as String?
                          ?? body['email']          as String?
                          ?? email;

        await _storage.guardarSesion(
          token:        token,
          refreshToken: refreshToken,
          nombre:       nombre,
          email:        emailResp,
          usuarioId:    userId,
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
  // RENOVAR TOKENS (POST /auth/refresh)
  // ══════════════════════════════════════════════════════════════════════════

  /// Renueva el access token usando el refresh token almacenado.
  ///
  /// Llama a `POST /auth/refresh` con el refresh token actual;
  /// si el servidor responde 200 guarda los nuevos tokens (rotación)
  /// y devuelve `true`. Si falla, devuelve `false`.
  static Future<bool> refreshTokens() async {
    try {
      final currentRefresh = await _storage.obtenerRefreshToken();
      if (currentRefresh == null || currentRefresh.isEmpty) return false;

      final response = await _client.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': currentRefresh}),
      );

      if (response.statusCode == 200) {
        final body       = jsonDecode(response.body) as Map<String, dynamic>;
        final newToken   = body['token']        as String? ?? '';
        final newRefresh = body['refreshToken'] as String? ?? '';

        if (newToken.isEmpty) return false;

        // Persistir los nuevos tokens rotados (solo tokens, datos de usuario sin cambio)
        await _storage.guardarNuevosTokens(
          token:        newToken,
          refreshToken: newRefresh,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
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
  // HELPERS PARA PAYLOAD DE FAVORITOS
  // ══════════════════════════════════════════════════════════════════════════

  /// Construye un objeto `ProductoFavorito` con el formato requerido por el backend:
  ///
  /// ```json
  /// { "productId": "<link>", "notificaciones": false }
  /// ```
  ///
  /// [productId] — identificador único del producto (usa el link del producto).
  /// [notificaciones] — si el usuario quiere recibir alertas de precio.
  static Map<String, dynamic> buildFavoritoPayload(
    String productId, {
    bool notificaciones = false,
  }) =>
      {'productId': productId, 'notificaciones': notificaciones};

  /// Convierte una lista de objetos favoritos del backend (o de la UI)
  /// al formato `[{productId, notificaciones}]` requerido por PATCH.
  ///
  /// Acepta tanto el formato antiguo (con campo `link`) como el nuevo
  /// (con campo `productId`) para compatibilidad durante la migración.
  static List<Map<String, dynamic>> normalizarFavoritos(
    List<dynamic> lista,
  ) {
    return lista.map((e) {
      if (e is Map<String, dynamic>) {
        // Formato nuevo: ya tiene productId
        if (e.containsKey('productId')) {
          return {
            'productId': e['productId'].toString(),
            'notificaciones': e['notificaciones'] as bool? ?? false,
          };
        }
        // Formato antiguo (legacy): tiene link, nombre, etc.
        final id = (e['link'] ?? e['nombre'] ?? '').toString();
        return {
          'productId': id,
          'notificaciones': e['notificaciones'] as bool? ?? false,
        };
      }
      // Si es un string crudo, usarlo como productId
      return {'productId': e.toString(), 'notificaciones': false};
    }).toList();
  }

}