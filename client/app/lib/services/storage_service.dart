import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Bu sınıf, JWT token'ı telefonun Keychain (iOS) veya
// Keystore (Android) bölümünde güvenle saklar.
class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'accessToken';

  // Token'ı kaydet
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Token'ı oku
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Token'ı sil (Çıkış yaparken)
  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }
}