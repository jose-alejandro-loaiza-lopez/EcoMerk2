import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ecomerk2/core/constants/env_config.dart';
import 'security_manager.dart';

/// Servicio para el endpoint de historial de precios de productos.
///
/// Según docs.md sección 4 — Base: `/productos`
/// - GET  /productos/{productId}/precios  → historial de precios
/// - POST /productos/{productId}/precios  → agregar nuevo precio
class ProductApiService {
  static String get baseUrl => EnvConfig.baseUrl;

  static http.Client get _client {
    return SecurityManager().client ?? http.Client();
  }

  /// Obtiene el historial de precios de un producto.
  ///
  /// Endpoint público (no requiere autenticación, pero sí cifrado RSA/SHA).
  /// Devuelve `{ productId, historial: [ {id, productId, precio, fechaGuardado} ] }`
  static Future<Map<String, dynamic>?> obtenerHistorial(
    String productId,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/productos/$productId/precios'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Agrega un nuevo precio al historial de un producto.
  ///
  /// Endpoint público (no requiere autenticación, pero sí cifrado RSA/SHA).
  /// Body: `{ "precio": double }`
  /// Primero consulta el último precio guardado; si es igual, omite el guardado.
  static Future<Map<String, dynamic>?> agregarPrecio({
    required String productId,
    required double precio,
  }) async {
    try {
      final historial = await obtenerHistorial(productId);
      if (historial != null) {
        final items = historial['historial'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          final ultimo = items.first['precio'];
          if (ultimo is num && ultimo.toDouble() == precio) {
            return null;
          }
        }
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/productos/$productId/precios'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'precio': precio}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
