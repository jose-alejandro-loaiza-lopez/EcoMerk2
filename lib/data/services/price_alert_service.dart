
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'market_api_service.dart';
import 'notification_service.dart';
import 'producto_api_service.dart';

/// Umbral mínimo de bajada de precio (en porcentaje) para disparar una alerta.
const double kPriceAlertThresholdPct = 5.0;

/// Clave usada en [SharedPreferences] para persistir el mapa de alertas.
const String _kPrefsKey = 'price_alerts_v2';

/// Servicio que gestiona las alertas de precio del usuario.
///
/// Almacena en [SharedPreferences] un mapa keyed por el **link** del producto:
/// ```json
/// {
///   "https://www.exito.com/leche-alqueria/p": {
///     "nombre": "Leche Alquería 1L",
///     "precioReferencia": 4200.0
///   }
/// }
/// ```
/// El link es único por producto y evita colisiones cuando varios productos
/// tienen el mismo nombre de fallback.
class PriceAlertService {
  // ── Persistencia ──────────────────────────────────────────────────────────

  /// Devuelve el mapa completo de alertas activas: {link → {nombre, precioReferencia}}.
  Future<Map<String, Map<String, dynamic>>> obtenerAlertas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
    );
  }

  /// Devuelve `true` si el usuario ya tiene una alerta para el producto con [link].
  Future<bool> estasSuscrito(String link) async {
    final alertas = await obtenerAlertas();
    return alertas.containsKey(link);
  }

  /// Registra una alerta para el producto identificado por [link].
  ///
  /// [nombre] es el nombre legible para mostrar en notificaciones.
  /// [precioActual] es el precio de referencia. Si es null o 0, se registra 0.0.
  Future<void> suscribir(String link, String nombre, double precioActual) async {
    final alertas = await obtenerAlertas();
    alertas[link] = {
      'nombre': nombre,
      'precioReferencia': precioActual,
    };
    await _guardar(alertas);
  }

  /// Elimina la alerta para el producto con [link]. No lanza error si no existía.
  Future<void> cancelar(String link) async {
    final alertas = await obtenerAlertas();
    alertas.remove(link);
    await _guardar(alertas);
  }

  Future<void> _guardar(Map<String, Map<String, dynamic>> alertas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(alertas));
  }

  // ── Verificación de cambios ───────────────────────────────────────────────

  /// Verifica todos los productos suscritos contra los precios actuales.
  ///
  /// Para cada producto cuyo precio bajó ≥ [kPriceAlertThresholdPct]%,
  /// dispara una notificación local y actualiza el precio de referencia.
  ///
  /// Diseñado para ser llamado desde [Workmanager] o manualmente.
  Future<void> verificarCambios() async {
    final alertas = await obtenerAlertas();
    if (alertas.isEmpty) return;

    for (final entry in alertas.entries) {
      final link = entry.key;
      final datos = entry.value;
      final nombre = (datos['nombre'] as String?) ?? link;
      final precioReferencia = (datos['precioReferencia'] as num?)?.toDouble() ?? 0.0;

      try {
        // Intentar obtener el precio actual directamente del link del producto
        final producto = await MarketApiService.obtenerProductoPorLink(link);
        if (producto == null) continue;

        final precioActual = (producto['precio'] as num?)?.toDouble() ?? 0.0;
        final tienda = (producto['tienda'] as String?) ?? '';

        if (precioActual <= 0 || precioReferencia <= 0) continue;

        // Registrar el precio actual en el historial del backend
        // (POST /productos/{productId}/precios — sin autenticación)
        unawaited(
          ProductoApiService.agregarPrecio(
            productId: link,
            precio: precioActual,
          ),
        );

        // Calculamos la variación porcentual
        final variacion =
            (precioReferencia - precioActual) / precioReferencia * 100;

        debugPrint(
          '[PriceAlert] $nombre: ref=\$${precioReferencia.toStringAsFixed(0)} '
          'actual=\$${precioActual.toStringAsFixed(0)} '
          'variación=${variacion.toStringAsFixed(1)}%',
        );

        if (variacion >= kPriceAlertThresholdPct) {
          // Disparar notificación
          await NotificationService.instance.mostrarAlertaDePrecio(
            nombre: nombre,
            tienda: tienda,
            precioAntes: precioReferencia,
            precioAhora: precioActual,
          );

          // Actualizar precio de referencia al nuevo precio
          alertas[link] = {
            'nombre': nombre,
            'precioReferencia': precioActual,
          };
          await _guardar(alertas);
        }
      } catch (e) {
        debugPrint('[PriceAlert] Error verificando "$nombre": $e');
      }
    }
  }
}
