import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      'https://usuarios-bd-production.up.railway.app/api/v1';

  // Guardar el token JWT localmente
  static Future<void> guardarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  // Obtener el token guardado
  static Future<String?> obtenerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // Borrar token (cerrar sesión)
  static Future<void> borrarToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('usuario_id');
  }

  // Guardar ID del usuario
  static Future<void> guardarUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('usuario_id', id);
  }

  // Obtener ID del usuario
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

// LOGIN
static Future<Map<String, dynamic>> login({
  required String email,
  required String password,
}) async {
  try {
    // Paso 1: hacer login para obtener el token
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
      final token = body['token'];
      await guardarToken(token);

      // Paso 2: buscar todos los usuarios para obtener el id
      // por ahora lo guardamos como 0 y lo obtenemos después
      final usuariosResponse = await http.get(
        Uri.parse('$baseUrl/usuarios/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (usuariosResponse.statusCode == 200) {
        final usuario = jsonDecode(usuariosResponse.body);
        await guardarUserId(usuario['id']);
      }

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

  // OBTENER USUARIO CON SU LISTA
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
        return jsonDecode(response.body);
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