import 'package:http/http.dart' as http;
import 'dart:convert';
import 'security_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      'https://usuarios-bd-production.up.railway.app/api/v1';

  static http.Client get _client {
    return SecurityManager().client ?? http.Client();
  }

  // ─── TOKEN ACCESS ────────────────────────────────────────────
  static Future<void> guardarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setInt(
      'token_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<String?> obtenerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<bool> tokenEstaVigente() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('token_timestamp');
    if (timestamp == null) return false;
    final guardadoEn = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diferencia = DateTime.now().difference(guardadoEn);
    return diferencia.inHours < 23;
  }

  // ─── REFRESH TOKEN ───────────────────────────────────────────
  static Future<void> guardarRefreshToken(String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refresh_token', refreshToken);
  }

  static Future<String?> obtenerRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  static Future<bool> renovarToken() async {
    try {
      final refreshToken = await obtenerRefreshToken();
      if (refreshToken == null) return false;

      final response = await _client.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        await guardarToken(body['token']);
        await guardarRefreshToken(body['refreshToken']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('refresh_token');
    await prefs.remove('usuario_id');
    await prefs.remove('token_timestamp');
    await prefs.remove('user_email');
    await prefs.remove('user_password');
  }

  // ─── USUARIO ID ──────────────────────────────────────────────
  static Future<void> guardarUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('usuario_id', id);
  }

  static Future<int?> obtenerUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('usuario_id');
  }

  static Future<void> guardarCredenciales(
      String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    await prefs.setString('user_password', password);
  }

  static Future<Map<String, String>?> obtenerCredenciales() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    final password = prefs.getString('user_password');
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
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
  static Future<bool> actualizarLista(int id, List<dynamic> lista) async {
    try {
      final token = await obtenerTokenValido();
      if (token == null) return false;

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

  static Future<List<dynamic>?> buscarProductos(String query) async {
    final token = await obtenerTokenValido();
    final response = await _client.get(
      Uri.parse('$baseUrl/productos?search=$query'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }
}