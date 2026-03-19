import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Login
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // null = éxito
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No existe una cuenta con este correo.';
        case 'wrong-password':
          return 'Contraseña incorrecta.';
        case 'invalid-email':
          return 'El correo no es válido.';
        default:
          return 'Error: ${e.message}';
      }
    }
  }

  // Registro
  Future<String?> register(String name, String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Guarda el nombre en el perfil
      await result.user?.updateDisplayName(name);
      return null; // null = éxito
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Este correo ya está registrado.';
        case 'weak-password':
          return 'La contraseña debe tener al menos 6 caracteres.';
        default:
          return 'Error: ${e.message}';
      }
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Estado del usuario actual
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}