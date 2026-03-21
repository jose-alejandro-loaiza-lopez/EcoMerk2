import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      'https://usuarios-bd-production.up.railway.app/api/v1';

  // Guardar token
  static Future<void> guardarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  // Obtener token
  static Future<String?> obtenerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // Borrar token
  static Future<void> borrarToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('usuario_id');
  }

  // Guardar ID
  static Future<void> guardarUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('usuario_id', id);
  }

  // Obtener ID
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
        return {
          'exito': false,
          'mensaje': body['mensaje'] ?? 'Error al registrarse'
        };
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'No se pudo conectar al servidor'};
    }
  }

  // LOGIN — el server devuelve id, mensaje y token
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        // El server devuelve: {"id": 3, "mensaje": "...", "token": "..."}
        await guardarToken(body['token']);
        await guardarUserId(body['id']);
        return {'exito': true};
      } else {
        return {
          'exito': false,
          'mensaje': 'Correo o contraseña incorrectos'
        };
      }
    } catch (e) {
      return {'exito': false, 'mensaje': 'No se pudo conectar al servidor'};
    }
  }

  // OBTENER USUARIO POR ID — devuelve usuario con su lista de favoritos
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
        // El server devuelve: {"usuario": {...}, "mensaje": "..."}
        return body['usuario'];
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
}