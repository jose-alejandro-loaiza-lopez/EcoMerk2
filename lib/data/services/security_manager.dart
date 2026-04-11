import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'secure_client.dart';

import 'user_api_service.dart';

class SecurityManager {
  static final SecurityManager _instance = SecurityManager._internal();
  factory SecurityManager() => _instance;
  SecurityManager._internal();

  SecureClient? _secureClient;
  final String _url = "${ApiService.baseUrl}/usuarios/public-key";

  SecureClient? get client => _secureClient;

  Future<void> refreshKeys() async {
    try {
      final response = await http.get(Uri.parse(_url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _secureClient = SecureClient(data['n'], data['e']);
        debugPrint("Seguridad: Llaves RSA actualizadas.");
      }
    } catch (e) {
      debugPrint("Error de red al obtener llaves: $e");
    }
  }
}
