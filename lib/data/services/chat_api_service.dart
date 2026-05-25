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

  static Future<Map<String, dynamic>?> obtenerMensajes({int? antes}) async {
    try {
      String url = '$baseUrl/chat/mensajes';
      if (antes != null) url += '?antes=$antes';

      final response = await ApiService.ejecutarConAuth((token) => _client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ));

      if (response == null) return null;
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> guardarMensaje({
    required String contenido,
    required bool esIa,
  }) async {
    try {
      final response = await ApiService.ejecutarConAuth((token) => _client.post(
        Uri.parse('$baseUrl/chat/mensajes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'contenido': contenido, 'esIa': esIa}),
      ));

      return response?.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// FASE 1: Envía el mensaje del usuario + favoritos a la IA.
  /// Retorna el mapa completo de la respuesta.
  static Future<Map<String, dynamic>?> preguntarIA(
    String mensaje,
    List<Map<String, dynamic>> favoritos,
  ) async {
    try {
      final response = await ApiService.ejecutarConAuth((token) => _client.post(
        Uri.parse('$baseUrl/chat/ia'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'mensaje': mensaje,
          'favoritos': favoritos,
        }),
      ));

      if (response == null) return null;
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// FASE 2: Reenvía el mensaje con los resultados de búsqueda obtenidos
  /// desde MarketApiService para que la IA dé una respuesta con datos reales.
  static Future<Map<String, dynamic>?> reenviarConResultados({
    required String mensaje,
    required List<Map<String, dynamic>> favoritos,
    required List<Map<String, dynamic>> resultadosBusqueda,
    required String toolCallId,
    required String arguments,
  }) async {
    try {
      final response = await ApiService.ejecutarConAuth((token) => _client.post(
        Uri.parse('$baseUrl/chat/ia'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'mensaje': mensaje,
          'favoritos': favoritos,
          'resultadosBusqueda': resultadosBusqueda,
          'toolCallId': toolCallId,
          'arguments': arguments,
        }),
      ));

      if (response == null) return null;
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
