import 'package:ecomerk2/data/services/user_api_service.dart';

class LoginService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    return await ApiService.login(email: email, password: password);
  }
}