import 'package:ecomerk2/data/services/user_api_service.dart';

class RegisterService {
  Future<Map<String, dynamic>> registrar({
    required String nombre,
    required String email,
    required String password,
    required String fechaNacimiento,
  }) async {
    return await ApiService.registrar(
      nombre: nombre,
      email: email,
      password: password,
      fechaNacimiento: fechaNacimiento,
    );
  }
}