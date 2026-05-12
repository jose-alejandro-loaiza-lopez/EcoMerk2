
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as encrypt;
import '../../core/utils/cripto_service.dart';
import '../models/encrypted_request_dto.dart';

class SecureClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final String n;
  final String e;

  SecureClient(this.n, this.e);



  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (n.isEmpty || e.isEmpty) {
      throw Exception("Seguridad no inicializada. Llama a refreshSecurity primero.");
    }
    encrypt.Key? currentAesKey;
    encrypt.IV? currentIv;

    // 1. PROCESAR SALIDA: Cifrar Request body
    if (request is http.Request && request.body.isNotEmpty) {
      final result = CriptoService.empaquetar(request.body, n, e);
      currentAesKey = result.aesKey;
      currentIv = result.iv;

      final dto = EncryptedRequestDTO(
        encryptedAesKey: result.bodyCifrado['encryptedAesKey'],
        iv: result.bodyCifrado['iv'],
        encryptedData: result.bodyCifrado['encryptedData'],
      );

      request.body = jsonEncode(dto.toJson());
      request.headers['Content-Type'] = 'application/json';
    }

    final response = await _inner.send(request);

    // 2. PROCESAR ENTRADA: Descifrar Response body
    if (currentAesKey != null && currentIv != null && response.statusCode == 200) {
      final bytes = await response.stream.toBytes();
      final responseBody = utf8.decode(bytes);

      final jsonResponse = jsonDecode(responseBody);

      // Verificamos si la respuesta viene en el formato DTO cifrado
      if (jsonResponse.containsKey('encryptedData')) {
        final dataDescifrada = CriptoService.desempaquetar(
            jsonResponse['encryptedData'],
            currentAesKey,
            currentIv
        );

        // Devolvemos un nuevo StreamedResponse con el JSON limpio
        return http.StreamedResponse(
          Stream.value(utf8.encode(dataDescifrada)),
          response.statusCode,
          headers: response.headers,
          request: response.request,
        );
      }
    }

    // Si no hay nada que descifrar, devolver respuesta original (convertida a stream de nuevo)
    return response;
  }
}