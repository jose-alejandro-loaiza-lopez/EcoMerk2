import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'user_api_service.dart';
import 'storage_service.dart';

/// Número máximo de mensajes por petición (constante del backend).
const int kCantidadPorPagina = 10;

/// Modelo de un mensaje del chat.
class MensajeChat {
  final int id;
  final int usuarioId;
  final String contenido;
  final bool esIa;

  const MensajeChat({
    required this.id,
    required this.usuarioId,
    required this.contenido,
    required this.esIa,
  });

  factory MensajeChat.fromJson(Map<String, dynamic> json) => MensajeChat(
        id: (json['id'] as num).toInt(),
        usuarioId: (json['usuarioId'] as num).toInt(),
        contenido: json['contenido'] as String? ?? '',
        esIa: json['esIa'] as bool? ?? false,
      );

  @override
  String toString() =>
      'MensajeChat(id=$id, esIa=$esIa, contenido=${contenido.substring(0, contenido.length.clamp(0, 30))}...)';
}

/// Resultado de `GET /chat/mensajes`.
class MensajesResponse {
  final List<MensajeChat> mensajes;
  final int cantidad;
  final bool hayMas;

  const MensajesResponse({
    required this.mensajes,
    required this.cantidad,
    required this.hayMas,
  });
}

/// Servicio para el chat privado de IA del usuario.
///
/// Endpoints consumidos:
///   GET  /chat/mensajes[?antes=<id>]  → mensajes del usuario (cursor-based, 10 por página)
///   POST /chat/mensajes               → guardar un mensaje (usuario o IA)
///
/// Autenticación: `Authorization: Bearer <ACCESS_TOKEN>` en ambas peticiones.
/// El `usuarioId` es inferido por el backend a partir del token — NO se envía.
class ChatApiService {
  static const String _baseUrl = ApiService.baseUrl;
  static final _storage = StorageService();

  // ── Obtener mensajes ────────────────────────────────────────────────────────

  /// Obtiene hasta [kCantidadPorPagina] mensajes del usuario autenticado.
  ///
  /// [antes] — cursor opcional: devuelve mensajes con `id < antes`.
  ///           Si es null, devuelve los más recientes.
  ///
  /// El backend devuelve los mensajes ordenados por `id` descendente
  /// (el primero es el más reciente).
  static Future<MensajesResponse?> obtenerMensajes({int? antes}) async {
    try {
      final token = await _storage.obtenerToken();
      if (token == null || token.isEmpty) return null;

      final uri = antes != null
          ? Uri.parse('$_baseUrl/chat/mensajes?antes=$antes')
          : Uri.parse('$_baseUrl/chat/mensajes');

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      debugPrint('[ChatApiService] GET /chat/mensajes → ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final lista = (body['mensajes'] as List<dynamic>? ?? [])
            .map((e) => MensajeChat.fromJson(e as Map<String, dynamic>))
            .toList();

        return MensajesResponse(
          mensajes: lista,
          cantidad: (body['cantidad'] as num?)?.toInt() ?? lista.length,
          hayMas: body['hayMas'] as bool? ?? false,
        );
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[ChatApiService] Token expirado al obtener mensajes.');
      }
    } catch (e) {
      debugPrint('[ChatApiService] obtenerMensajes error: $e');
    }
    return null;
  }

  // ── Guardar mensaje ─────────────────────────────────────────────────────────

  /// Guarda un mensaje en el backend.
  ///
  /// [contenido] — texto del mensaje (obligatorio).
  /// [esIa] — `true` si el mensaje es de la IA, `false` si es del usuario.
  ///
  /// **No se envía `usuarioId`** — el backend lo infiere del token.
  ///
  /// Devuelve el [MensajeChat] guardado, o `null` si falló.
  static Future<MensajeChat?> guardarMensaje({
    required String contenido,
    required bool esIa,
  }) async {
    try {
      final token = await _storage.obtenerToken();
      if (token == null || token.isEmpty) return null;

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/mensajes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'contenido': contenido, 'esIa': esIa}),
      );

      debugPrint('[ChatApiService] POST /chat/mensajes → ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // El backend devuelve { "mensaje": "...", "datos": { id, usuarioId, contenido, esIa } }
        final datos = body['datos'] as Map<String, dynamic>?;
        if (datos != null) {
          return MensajeChat.fromJson(datos);
        }
      }
    } catch (e) {
      debugPrint('[ChatApiService] guardarMensaje error: $e');
    }
    return null;
  }
}
