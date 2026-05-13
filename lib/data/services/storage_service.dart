import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio centralizado de almacenamiento que separa datos sensibles
/// de datos no-sensibles.
///
/// **FlutterSecureStorage** (cifrado en Keychain/Keystore):
///   - `jwt_token` — access token JWT
///   - `refresh_token` — refresh token para renovar sesión
///   - `user_email` — correo del usuario (credencial)
///   - `user_password` — contraseña del usuario (credencial)
///
/// **SharedPreferences** (texto plano, no sensible):
///   - `token_timestamp` — momento en que se guardó el token
///   - `usuario_id` — ID numérico del usuario
///   - `navigation_mode` — preferencia de UI
///   - `price_alerts` — mapa de alertas de precio
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  // Android: encryptedSharedPreferences para cifrado AES-256
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ══════════════════════════════════════════════════════════════
  //  DATOS SENSIBLES → FlutterSecureStorage
  // ══════════════════════════════════════════════════════════════

  // ─── ACCESS TOKEN ───────────────────────────────────────────
  Future<void> guardarToken(String token) async {
    await _secureStorage.write(key: 'jwt_token', value: token);
    // El timestamp sigue en SharedPreferences (no es sensible)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'token_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<String?> obtenerToken() async {
    return await _secureStorage.read(key: 'jwt_token');
  }

  // ─── REFRESH TOKEN ──────────────────────────────────────────
  Future<void> guardarRefreshToken(String refreshToken) async {
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<String?> obtenerRefreshToken() async {
    return await _secureStorage.read(key: 'refresh_token');
  }

  // ─── CREDENCIALES ───────────────────────────────────────────
  Future<void> guardarCredenciales(String email, String password) async {
    await _secureStorage.write(key: 'user_email', value: email);
    await _secureStorage.write(key: 'user_password', value: password);
  }

  Future<Map<String, String>?> obtenerCredenciales() async {
    final email = await _secureStorage.read(key: 'user_email');
    final password = await _secureStorage.read(key: 'user_password');
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════
  //  DATOS NO-SENSIBLES → SharedPreferences
  // ══════════════════════════════════════════════════════════════

  // ─── TOKEN TIMESTAMP ────────────────────────────────────────
  Future<bool> tokenEstaVigente() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('token_timestamp');
    if (timestamp == null) return false;
    final guardadoEn = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diferencia = DateTime.now().difference(guardadoEn);
    return diferencia.inHours < 23;
  }

  // ─── USUARIO ID ─────────────────────────────────────────────
  Future<void> guardarUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('usuario_id', id);
  }

  Future<int?> obtenerUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('usuario_id');
  }

  // ══════════════════════════════════════════════════════════════
  //  BORRAR TODO (logout / eliminar cuenta)
  // ══════════════════════════════════════════════════════════════

  /// Borra todos los datos de sesión (sensibles y no sensibles).
  Future<void> borrarSesion() async {
    // Sensibles
    await _secureStorage.delete(key: 'jwt_token');
    await _secureStorage.delete(key: 'refresh_token');
    await _secureStorage.delete(key: 'user_email');
    await _secureStorage.delete(key: 'user_password');

    // No sensibles
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token_timestamp');
    await prefs.remove('usuario_id');
  }
}
