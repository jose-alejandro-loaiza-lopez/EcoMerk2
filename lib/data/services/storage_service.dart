import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio de almacenamiento local segmentado.
///
/// Aplica el principio de separación de sensibilidad:
/// - Datos NO sensibles (nombre, email, userId, timestamp) →
///   [SharedPreferences]: persistencia estándar.
/// - Datos SENSIBLES (access_token JWT, refresh_token) →
///   [FlutterSecureStorage]: cifrado en Keystore (Android) / Keychain (iOS).
class StorageService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // ── Instancia de almacenamiento seguro ────────────────────────────────────
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Claves internas ───────────────────────────────────────────────────────
  static const String _kToken        = 'access_token';    // SecureStorage
  static const String _kRefreshToken = 'refresh_token';   // SecureStorage
  static const String _kNombre       = 'user_nombre';     // SharedPreferences
  static const String _kEmail        = 'user_email';      // SharedPreferences
  static const String _kUserId       = 'usuario_id';      // SharedPreferences
  static const String _kTimestamp    = 'token_timestamp'; // SharedPreferences

  // ══════════════════════════════════════════════════════════════════════════
  // GUARDAR SESIÓN COMPLETA
  // ══════════════════════════════════════════════════════════════════════════

  /// Persiste todos los datos de la sesión tras un login exitoso.
  ///
  /// - [token] y [refreshToken] se guardan en [FlutterSecureStorage] (cifrado).
  /// - [nombre], [email], [usuarioId] y timestamp en [SharedPreferences].
  Future<void> guardarSesion({
    required String token,
    required String refreshToken,
    required String nombre,
    required String email,
    required int usuarioId,
  }) async {
    // Tokens sensibles en almacenamiento seguro (cifrado)
    await _secureStorage.write(key: _kToken, value: token);
    await _secureStorage.write(key: _kRefreshToken, value: refreshToken);

    // Datos no sensibles en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNombre, nombre);
    await prefs.setString(_kEmail, email);
    await prefs.setInt(_kUserId, usuarioId);
    await prefs.setInt(_kTimestamp, DateTime.now().millisecondsSinceEpoch);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RENOVAR TOKENS (POST /auth/refresh)
  // ══════════════════════════════════════════════════════════════════════════

  /// Actualiza solo los tokens tras una rotación exitosa (`/auth/refresh`).
  ///
  /// No modifica datos no sensibles del usuario (nombre, email, userId).
  Future<void> guardarNuevosTokens({
    required String token,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _kToken, value: token);
    await _secureStorage.write(key: _kRefreshToken, value: refreshToken);
    // Actualizar timestamp para reiniciar el contador de vigencia
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTimestamp, DateTime.now().millisecondsSinceEpoch);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LECTURA
  // ══════════════════════════════════════════════════════════════════════════

  /// Devuelve el access token JWT desde SecureStorage, o `null` si no existe.
  Future<String?> obtenerToken() => _secureStorage.read(key: _kToken);

  /// Devuelve el refresh token desde SecureStorage, o `null` si no existe.
  Future<String?> obtenerRefreshToken() =>
      _secureStorage.read(key: _kRefreshToken);

  /// Devuelve el ID de usuario desde SharedPreferences.
  Future<int?> obtenerUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kUserId);
  }

  /// Devuelve el nombre del usuario desde SharedPreferences.
  Future<String?> obtenerNombre() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kNombre);
  }

  /// Devuelve el email del usuario desde SharedPreferences.
  Future<String?> obtenerEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kEmail);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDACIÓN DE TOKEN
  // ══════════════════════════════════════════════════════════════════════════

  /// Verifica si el token almacenado está dentro del período de vigencia (23h).
  Future<bool> tokenEstaVigente() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_kTimestamp);
    if (timestamp == null) return false;
    final guardadoEn = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(guardadoEn).inHours < 23;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIMPIAR SESIÓN
  // ══════════════════════════════════════════════════════════════════════════

  /// Elimina todos los datos de sesión de ambos storages.
  ///
  /// Llamar siempre que el usuario cierre sesión o el token expire.
  Future<void> limpiarSesion() async {
    // Tokens del almacenamiento seguro
    await _secureStorage.delete(key: _kToken);
    await _secureStorage.delete(key: _kRefreshToken);

    // Datos no sensibles de SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kNombre);
    await prefs.remove(_kEmail);
    await prefs.remove(_kUserId);
    await prefs.remove(_kTimestamp);
    // Claves legacy para retrocompatibilidad con versiones anteriores
    await prefs.remove('jwt_token');
    await prefs.remove('user_password');
  }
}
