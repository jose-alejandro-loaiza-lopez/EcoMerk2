import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ecomerk2/core/constants/env_config.dart';

/// Servicio para el endpoint de historial de precios de productos.
///
/// Según docs.md sección 4 — Base: `/productos`
/// - GET  /productos/{productId}/precios  → historial de precios
/// - POST /productos/{productId}/precios  → agregar nuevo precio
class ProductApiService {
  static String get baseUrl => EnvConfig.baseUrl;

  /// Obtiene el historial de precios de un producto.
  ///
  /// Endpoint público (no requiere autenticación).
  /// Devuelve `{ productId, historial: [ {id, productId, precio, fechaGuardado} ] }`
  static Future<Map<String, dynamic>?> obtenerHistorial(
    String productId,
  ) async {
    try {
      final response = await http.get(
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
  /// Endpoint público (no requiere autenticación).
  /// Body: `{ "precio": double }`
  static Future<Map<String, dynamic>?> agregarPrecio({
    required String productId,
    required double precio,
  }) async {
    try {
      final response = await http.post(
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
