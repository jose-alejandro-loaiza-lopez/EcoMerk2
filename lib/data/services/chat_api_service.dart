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
        body: jsonEncode({'contenido': contenido, 'esIa': esIa}),
      );

      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static String _buildSystemPrompt(List<Map<String, dynamic>> favoritos) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Eres EcoIA, el asistente experto en ahorro de EcoMerk2 en Colombia. '
      'Tu objetivo es ayudar con cocina económica y gestión de presupuesto. '
      'Además, puedes usar Markdown para formatear tus respuestas y hacerlas más claras y atractivas.\n'
      'REGLAS DE FORMATO Y RESPUESTA:\n'
      '- Usa **negritas** para resaltar precios y nombres de productos.\n'
      '- Usa ### para títulos de secciones (ej. ### Receta Sugerida).\n'
      '- Usa listas con guiones para ingredientes o pasos.\n'
      '- Mantén un tono amable, natural y colombiano.\n'
      '- No tienes historial chat\n'
      '- Si recomiendas productos, prioriza los favoritos del usuario.\n'
      '- Si el usuario pide recetas, recomiendalas por mayor coincidencia con la lista de favoritos del usuario.\n'
      '- Si el usuario no tiene favoritos, recomienda cualquier receta.',
    );

    if (favoritos.isNotEmpty) {
      buffer.writeln(
        '\n### PRODUCTOS FAVORITOS DEL USUARIO (Contexto Real) ###',
      );
      for (final f in favoritos) {
        final nombre = f['nombre'] ?? 'Producto';
        final tienda = f['tienda'] ?? 'Tienda desconocida';
        final precio = f['precio'] ?? 'Sin precio';

        // Formateamos el precio para que la IA entienda que es COP
        buffer.writeln('- $nombre en $tienda: \$ $precio COP');
      }
      buffer.writeln('### FIN DE DATOS ###');
    }

    return buffer.toString();
  }

  /// Envía un mensaje a OpenRouter con el contexto de favoritos y
  /// devuelve la respuesta de la IA.
  static Future<String?> preguntarIA(
    String mensaje,
    List<Map<String, dynamic>> favoritos,
  ) async {
    try {
      final apiKey = EnvConfig.openRouterApiKey;
      if (apiKey.isEmpty) return null;

      final systemPrompt = _buildSystemPrompt(favoritos);

      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'openai/gpt-oss-120b:free',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': mensaje},
          ],
          'reasoning': {'enabled': true},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
