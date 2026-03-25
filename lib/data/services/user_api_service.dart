import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      'https://usuarios-bd-production.up.railway.app/api/v1';

  static Future<void> guardarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    // Guardar timestamp de cuando se guardó el token
    await prefs.setInt('token_timestamp', DateTime.now().millisecondsSinceEpoch);
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
    // Token válido por 23 horas (1 hora de margen antes de las 24h)
    return diferencia.inHours < 23;
  }

  static Future<void> borrarToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('usuario_id');
    await prefs.remove('token_timestamp');
  }

  static Future<void> guardarUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('usuario_id', id);
  }

  static Future<int?> obtenerUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('usuario_id');
  }

  // REGISTRO
  static Future<Map<String, dynamic>> registrar({
    required String nombre,
    required String email,
    required String password,
    required String fechaNacimiento,
  }) async {
    try {
      final response = await http.post(
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
        return {'exito': false, 'mensaje': body['mensaje'] ?? 'Error al registrarse'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'No se pudo conectar al servidor'};
    }
  }

  // LOGIN
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        await guardarToken(body['token']);
        await guardarUserId(body['id']);
        return {'exito': true};
      } else {
        return {'exito': false, 'mensaje': 'Correo o contraseña incorrectos'};
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'No se pudo conectar al servidor'};
    }
  }

  // OBTENER USUARIO — con detección de token expirado
  static Future<Map<String, dynamic>?> obtenerUsuario(int id) async {
    try {
      final token = await obtenerToken();
      final response = await http.get(
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
      // Token expirado o no autorizado
      if (response.statusCode == 401 || response.statusCode == 403) {
        return {'_tokenExpirado': true};
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ACTUALIZAR LISTA DE FAVORITOS
  static Future<bool> actualizarLista(int id, List<String> lista) async {
    try {
      final token = await obtenerToken();
      final response = await http.patch(
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
    final response = await http.get(
      Uri.parse('$baseUrl/productos?search=$query'),
      headers: {'Authorization': 'Bearer ${await obtenerToken()}'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }
}