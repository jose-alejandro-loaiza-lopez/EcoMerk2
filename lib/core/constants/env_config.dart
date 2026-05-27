import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._();

  static Future<void> init() async {
    await dotenv.load(fileName: '.env');
  }

  static String _get(String key) {
    final value = dotenv.env[key];
    if (value == null) {
      throw Exception('Variable de entorno $key no encontrada en .env');
    }
    return value;
  }

  static String get baseUrl => _get('BASE_URL');
  static String get exitoApiUrl => _get('EXITO_API_URL');
  static String get exitoWebUrl => _get('EXITO_WEB_URL');
  static String get olimpicaApiUrl => _get('OLIMPICA_API_URL');
  static String get surtifamiliarApiSearchUrl => _get('SURTIFAMILIAR_API_SEARCH_URL');
  static String get surtifamiliarApiDetailUrl => _get('SURTIFAMILIAR_API_DETAIL_URL');
  static String get surtifamiliarImagesUrl => _get('SURTIFAMILIAR_IMAGES_URL');
  static String get surtifamiliarNoImageUrl => _get('SURTIFAMILIAR_NO_IMAGE_URL');
  static String get surtifamiliarWebUrl => _get('SURTIFAMILIAR_WEB_URL');
  static String get userAgentExito => _get('USER_AGENT_EXITO');
  static String get userAgentOlimpica => _get('USER_AGENT_OLIMPICA');
  static String get userAgentSurtifamiliar => _get('USER_AGENT_SURTIFAMILIAR');
  static String get userAgentSurtifamiliarDetail => _get('USER_AGENT_SURTIFAMILIAR_DETAIL');
}
