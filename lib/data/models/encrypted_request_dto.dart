class EncryptedRequestDTO {
  final String? encryptedAesKey;
  final String iv;
  final String encryptedData;

  EncryptedRequestDTO({
    this.encryptedAesKey,
    required this.iv,
    required this.encryptedData,
  });

  Map<String, dynamic> toJson() => {
    'encryptedAesKey': encryptedAesKey,
    'iv': iv,
    'encryptedData': encryptedData,
  };

  factory EncryptedRequestDTO.fromJson(Map<String, dynamic> json) {
    return EncryptedRequestDTO(
      encryptedAesKey: json['encryptedAesKey'],
      iv: json['iv'],
      encryptedData: json['encryptedData'],
    );
  }
}