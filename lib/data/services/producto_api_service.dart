import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'user_api_service.dart';

/// Modelo de un punto histórico de precio.
class PrecioHistorico {
  final int id;
  final String productId;
  final double precio;
  final String fechaGuardado;

  const PrecioHistorico({
    required this.id,
    required this.productId,
    required this.precio,
    required this.fechaGuardado,
  });

  factory PrecioHistorico.fromJson(Map<String, dynamic> json) =>
      PrecioHistorico(
        id: (json['id'] as num).toInt(),
        productId: json['productId']?.toString() ?? '',
        precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
        fechaGuardado: json['fechaGuardado']?.toString() ?? '',
      );
}

/// Servicio para el historial de precios de productos.
///
/// Endpoints consumidos (ambos sin autenticación según docs.md):
///   GET  /productos/{productId}/precios  → historial de precios
///   POST /productos/{productId}/precios  → agregar nuevo precio al historial
///
/// `productId` es el identificador único del producto (string).
/// En la app se usa el **link** del producto como `productId`.
class ProductoApiService {
  static const String _baseUrl = ApiService.baseUrl;

  // ── Obtener historial ───────────────────────────────────────────────────────

  /// Devuelve el historial de precios del producto [productId].
  ///
  /// La lista está ordenada por `fechaGuardado` descendente
  /// (el primer elemento es el precio más reciente).
  ///
  /// Devuelve una lista vacía si no hay precios o si hay error.
  static Future<List<PrecioHistorico>> obtenerHistorial(
      String productId) async {
    try {
      final encodedId = Uri.encodeComponent(productId);
      final response = await http.get(
        Uri.parse('$_baseUrl/productos/$encodedId/precios'),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint(
          '[ProductoApiService] GET /productos/.../precios → ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final lista = (body['historial'] as List<dynamic>? ?? [])
            .map((e) =>
                PrecioHistorico.fromJson(e as Map<String, dynamic>))
            .toList();
        return lista;
      }
    } catch (e) {
      debugPrint('[ProductoApiService] obtenerHistorial error: $e');
    }
    return [];
  }

  // ── Agregar precio ──────────────────────────────────────────────────────────

  /// Agrega un nuevo punto al historial de precios del producto [productId].
  ///
  /// [precio] — precio actual del producto (obligatorio, > 0).
  ///
  /// Devuelve el [PrecioHistorico] guardado, o `null` si falló.
  static Future<PrecioHistorico?> agregarPrecio({
    required String productId,
    required double precio,
  }) async {
    try {
      final encodedId = Uri.encodeComponent(productId);
      final response = await http.post(
        Uri.parse('$_baseUrl/productos/$encodedId/precios'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'precio': precio}),
      );

      debugPrint(
          '[ProductoApiService] POST /productos/.../precios → ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // Respuesta: { "mensaje": "...", "precio": { id, productId, precio, fechaGuardado } }
        final precioObj = body['precio'] as Map<String, dynamic>?;
        if (precioObj != null) {
          return PrecioHistorico.fromJson(precioObj);
        }
      }
    } catch (e) {
      debugPrint('[ProductoApiService] agregarPrecio error: $e');
    }
    return null;
  }
}
