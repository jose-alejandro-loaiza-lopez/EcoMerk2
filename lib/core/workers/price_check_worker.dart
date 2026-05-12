
import 'package:workmanager/workmanager.dart';
import '../../../data/services/price_alert_service.dart';
import '../../../data/services/notification_service.dart';

/// Nombre único de la tarea periódica registrada en Workmanager.
const String kPriceCheckTask = 'com.ecomerk2.priceCheck';

/// Frecuencia del polling de precios en background.
const Duration kPriceCheckFrequency = Duration(hours: 6);

/// Función top-level requerida por Workmanager.
/// Debe ser una función de nivel superior (no un método de clase).
@pragma('vm:entry-point')
void priceCheckCallback() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == kPriceCheckTask) {
      // Inicializamos el servicio de notificaciones en el isolate de background
      await NotificationService.instance.init();
      await PriceAlertService().verificarCambios();
    }
    return Future.value(true);
  });
}
