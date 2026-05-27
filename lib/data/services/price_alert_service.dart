import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'market_api_service.dart';
import 'notification_service.dart';

/// Clave usada en [SharedPreferences] para persistir el mapa de alertas.
const String _kPrefsKey = 'price_alerts';

/// Servicio que gestiona las alertas de precio del usuario.
///
/// Almacena en [SharedPreferences] un mapa:
/// ```json
/// { "Leche Alquería 1L": 4200.0, "Arroz Diana 1kg": 3500.0 }
/// ```
/// donde el valor es el **precio de referencia** en el momento de suscripción.
class PriceAlertService {
  // ── Persistencia ──────────────────────────────────────────────────────────

  /// Devuelve el mapa completo de alertas activas: {nombre → precioReferencia}.
  Future<Map<String, double>> obtenerAlertas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  /// Devuelve `true` si el usuario ya tiene una alerta para [nombre].
  Future<bool> estasSuscrito(String nombre) async {
    final alertas = await obtenerAlertas();
    return alertas.containsKey(nombre);
  }

  /// Registra una alerta para [nombre] usando [precioActual] como referencia.
  ///
  /// Si ya existía una alerta, actualiza el precio de referencia.
  Future<void> suscribir(String nombre, double precioActual) async {
    final alertas = await obtenerAlertas();
    alertas[nombre] = precioActual;
    await _guardar(alertas);
  }

  /// Elimina la alerta para [nombre]. No lanza error si no existía.
  Future<void> cancelar(String nombre) async {
    final alertas = await obtenerAlertas();
    alertas.remove(nombre);
    await _guardar(alertas);
  }

  Future<void> _guardar(Map<String, double> alertas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(alertas));
  }

  // ── Verificación de cambios ───────────────────────────────────────────────

  /// Verifica todos los productos suscritos contra los precios actuales.
  ///
  /// Para cada producto cuyo precio haya cambiado (subido o bajado),
  /// dispara una notificación local y actualiza el precio de referencia.
  ///
  /// Diseñado para ser llamado desde [Workmanager] o manualmente.
  Future<void> verificarCambios() async {
    final alertas = await obtenerAlertas();
    if (alertas.isEmpty) return;

    for (final entry in alertas.entries) {
      final nombre = entry.key;
      final precioReferencia = entry.value;

      try {
        final resultados = await MarketApiService.buscarEnTiendas(nombre);
        if (resultados.isEmpty) continue;

        // Tomamos el precio más bajo encontrado
        final mejor = resultados.reduce(
          (a, b) => (a['precio'] as num) < (b['precio'] as num) ? a : b,
        );
        final precioActual = (mejor['precio'] as num).toDouble();
        final tienda = mejor['tienda'].toString();

        // Calculamos la variación porcentual
        final variacion =
            (precioReferencia - precioActual) / precioReferencia * 100;

        debugPrint(
          '[PriceAlert] $nombre: ref=\$${precioReferencia.toStringAsFixed(0)} '
          'actual=\$${precioActual.toStringAsFixed(0)} '
          'variación=${variacion.toStringAsFixed(1)}%',
        );

        if (variacion != 0) {
          final subio = variacion < 0;

          await NotificationService.instance.mostrarAlertaDePrecio(
            nombre: nombre,
            tienda: tienda,
            precioAntes: precioReferencia,
            precioAhora: precioActual,
            subio: subio,
          );

          // Actualizar precio de referencia al nuevo precio
          alertas[nombre] = precioActual;
          await _guardar(alertas);
        }
      } catch (e) {
        debugPrint('[PriceAlert] Error verificando "$nombre": $e');
      }
    }
  }
}
