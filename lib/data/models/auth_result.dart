/// Resultado sellado del proceso de autenticación JWT.
///
/// Representa los tres estados posibles:
/// - [AuthLoading]: la petición está en curso
/// - [AuthSuccess]: login exitoso con token y datos de usuario
/// - [AuthError]: fallo con un mensaje descriptivo
sealed class AuthResult {}

/// Estado intermedio mientras se espera respuesta del servidor.
class AuthLoading extends AuthResult {}

/// Login completado exitosamente.
class AuthSuccess extends AuthResult {
  /// Access token JWT recibido del backend.
  final String token;

  /// Refresh token recibido del backend (rotación; dura 7 días).
  final String refreshToken;

  /// Nombre del usuario autenticado.
  final String nombre;

  /// Correo electrónico del usuario autenticado.
  final String email;

  /// ID del usuario en el backend.
  final int usuarioId;

  AuthSuccess({
    required this.token,
    required this.refreshToken,
    required this.nombre,
    required this.email,
    required this.usuarioId,
  });
}

/// Fallo en el proceso de autenticación.
class AuthError extends AuthResult {
  /// Mensaje descriptivo del error (para mostrar al usuario).
  final String mensaje;

  AuthError({required this.mensaje});
}
