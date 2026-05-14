import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración centralizada de variables de entorno.
///
/// Usa [flutter_dotenv] para cargar valores desde el archivo `.env`.
/// Debe llamarse `await EnvConfig.init()` antes de usar cualquier valor.
class EnvConfig {
  EnvConfig._();

  /// Inicializa la configuración cargando el archivo `.env`.
  /// Llamar una sola vez en `main()` antes de `runApp`.
  static Future<void> init() async {
    await dotenv.load(fileName: '.env');
  }

  /// URL base del backend (ej: `https://…/api/v1`).
  /// Cambia el valor en `.env` para apuntar a otro servidor.
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'https://usuarios-bd-production.up.railway.app/api/v1';

}
