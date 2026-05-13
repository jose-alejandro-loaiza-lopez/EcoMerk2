import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_api_service.dart';
import 'security_manager.dart';
import 'package:ecomerk2/core/constants/env_config.dart';

class ChatApiService {
  static String get baseUrl => EnvConfig.baseUrl;

  static http.Client get _client {
    return SecurityManager().client ?? http.Client();
  }

  // Obtener historial de mensajes (paginado por cursor)
  static Future<Map<String, dynamic>?> obtenerMensajes({int? antes}) async {
    try {
      final token = await ApiService.obtenerTokenValido();
      if (token == null) return null;

      String url = '$baseUrl/chat/mensajes';
      if (antes != null) url += '?antes=$antes';

      final response = await _client.get(
        Uri.parse(url),
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

  // Guardar un mensaje (usuario o IA)
  static Future<bool> guardarMensaje({
    required String contenido,
    required bool esIa,
  }) async {
    try {
      final token = await ApiService.obtenerTokenValido();
      if (token == null) return false;

      final response = await _client.post(
        Uri.parse('$baseUrl/chat/mensajes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contenido': contenido,
          'esIa': esIa,
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}