import '../../data/services/price_alert_service.dart';

/// Controlador para la lógica de alertas de precio.
///
/// Sigue el mismo patrón que [LoginController] y [RegisterController]:
/// delega toda la lógica al servicio correspondiente, sin estado de UI.
///
/// Usa el **link** del producto como identificador único en lugar del nombre,
/// para evitar colisiones entre productos con nombres idénticos.
class PriceAlertController {
  final PriceAlertService _service = PriceAlertService();

  /// Devuelve `true` si el usuario tiene una alerta activa para el producto
  /// identificado por [link].
  Future<bool> estasSuscrito(String link) => _service.estasSuscrito(link);

  /// Suscribe al usuario a cambios de precio del producto con [link].
  ///
  /// [nombre] es el nombre legible del producto (para notificaciones).
  /// [precioActual] es el precio de referencia base para detectar cambios.
  /// Si [precioActual] es null o 0, registra 0.0 como referencia.
  Future<void> suscribir(String link, String nombre, double? precioActual) =>
      _service.suscribir(link, nombre, precioActual ?? 0.0);

  /// Cancela la alerta de precio para el producto con [link].
  Future<void> cancelar(String link) => _service.cancelar(link);

  /// Fuerza una verificación inmediata de todos los productos suscritos.
  /// Útil para depuración o para refrescar desde la UI.
  Future<void> verificarAhora() => _service.verificarCambios();
}
