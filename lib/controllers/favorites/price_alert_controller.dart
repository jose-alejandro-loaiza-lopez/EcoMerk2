import '../../data/services/price_alert_service.dart';

/// Controlador para la lógica de alertas de precio.
///
/// Sigue el mismo patrón que [LoginController] y [RegisterController]:
/// delega toda la lógica al servicio correspondiente, sin estado de UI.
class PriceAlertController {
  final PriceAlertService _service = PriceAlertService();

  /// Devuelve `true` si el usuario tiene una alerta activa para [nombre].
  Future<bool> estasSuscrito(String nombre) =>
      _service.estasSuscrito(nombre);

  /// Suscribe al usuario a cambios de precio del producto [nombre].
  ///
  /// [precioActual] es el precio de referencia base para detectar cambios.
  /// Si [precioActual] es null o 0, registra 0.0 como referencia.
  Future<void> suscribir(String nombre, double? precioActual) =>
      _service.suscribir(nombre, precioActual ?? 0.0);

  /// Cancela la alerta de precio para el producto [nombre].
  Future<void> cancelar(String nombre) => _service.cancelar(nombre);

  /// Fuerza una verificación inmediata de todos los productos suscritos.
  /// Útil para depuración o para refrescar desde la UI.
  Future<void> verificarAhora() => _service.verificarCambios();
}
