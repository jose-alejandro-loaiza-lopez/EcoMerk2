import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton que encapsula [FlutterLocalNotificationsPlugin].
/// Inicializar con [init] antes de usar cualquier otro método.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Inicializa el plugin y solicita permisos (Android 13+ / iOS).
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // Solicitar permiso explícito en Android 13+
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Muestra una notificación de alerta de precio.
  ///
  /// [nombre] nombre del producto.
  /// [tienda] tienda donde se encontró el nuevo precio.
  /// [precioAntes] precio de referencia guardado.
  /// [precioAhora] precio actual encontrado.
  Future<void> mostrarAlertaDePrecio({
    required String nombre,
    required String tienda,
    required double precioAntes,
    required double precioAhora,
  }) async {
    if (!_initialized) await init();

    final diferencia = ((precioAntes - precioAhora) / precioAntes * 100)
        .abs()
        .toStringAsFixed(0);

    final titulo = '📉 Precio bajó $diferencia% — $nombre';
    final cuerpo =
        'Ahora: \$${_fmt(precioAhora)} en $tienda (antes \$${_fmt(precioAntes)})';

    const androidDetails = AndroidNotificationDetails(
      'price_alerts',
      'Alertas de precio',
      channelDescription: 'Notificaciones cuando baja el precio de un favorito',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      nombre.hashCode.abs() % 10000, // ID único por producto
      titulo,
      cuerpo,
      details,
    );
  }

  String _fmt(double precio) =>
      precio.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
}
