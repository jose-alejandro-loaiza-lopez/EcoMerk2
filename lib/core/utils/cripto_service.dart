
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';

class CriptoResult {
  final Map<String, dynamic> bodyCifrado;
  final Key aesKey;
  final IV iv;

  CriptoResult(this.bodyCifrado, this.aesKey, this.iv);
}

class CriptoService {
  static RSAPublicKey _parsePublicKey(String nHex, String eHex) {
    return RSAPublicKey(
      BigInt.parse(nHex, radix: 16),
      BigInt.parse(eHex, radix: 16),
    );
  }

  // Ahora retorna el DTO, pero también la llave y el IV para desencriptar la respuesta
  static CriptoResult empaquetar(String jsonBody, String n, String e) {
    final iv = IV.fromSecureRandom(16);
    final aesKey = Key.fromSecureRandom(16);
    final publicKey = _parsePublicKey(n, e);

    final encrypterAes = Encrypter(
      AES(aesKey, mode: AESMode.cbc, padding: 'PKCS7'),
    );
    final encryptedData = encrypterAes.encrypt(jsonBody, iv: iv);

    final encrypterRsa = Encrypter(RSA(publicKey: publicKey));
    final encryptedKey = encrypterRsa.encryptBytes(aesKey.bytes);

    final dto = {
      "encryptedData": encryptedData.base64,
      "encryptedAesKey": encryptedKey.base64,
      "iv": iv.base64,
    };

    return CriptoResult(dto, aesKey, iv);
  }

  // Nuevo método para abrir la respuesta del servidor
  static String desempaquetar(String dataCifradaBase64, Key aesKey, IV iv) {
    try {
      final encrypterAes = Encrypter(
        AES(aesKey, mode: AESMode.cbc, padding: 'PKCS7'),
      );
      final encrypted = Encrypted.fromBase64(dataCifradaBase64);
      return encrypterAes.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception("Error descifrando la respuesta del servidor: $e");
    }
  }
}
