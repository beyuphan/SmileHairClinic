import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  // Android Emülatör için 'localhost' 10.0.2.2'dir.
  // iOS Simülatör veya gerçek cihaz için local IP'ni (örn: 192.168.1.10) yazmalısın.
  static const String _baseUrl = "http://192.168.1.21:3000";

  ApiService()
      : _dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          )
        ),
        _secureStorage = const FlutterSecureStorage() {

    // KRİTİK ADIM: INTERCEPTOR (ÖNLEYİCİ)
    // Bu kod, atılan HER İSTEKTEN önce çalışır.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 1. Güvenli depodan token'ı oku
          final token = await _secureStorage.read(key: 'accessToken');

          // 2. Token varsa, isteğin 'Authorization' başlığına ekle
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // 3. İsteğin devam etmesine izin ver
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Hata yönetimi (şimdilik basit tutalım)
          print("API Hatası: ${e.message}");
          return handler.next(e);
        },
      ),
    );
  }

  // --- HAMLE 1: LOGIN ---
  Future<String> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      // Gelen cevaptaki 'accessToken'ı çekip döndür
      return response.data['accessToken'];
    } catch (e) {
      rethrow; // Hatayı BLoC'un yakalaması için yeniden fırlat
    }
  }

  // --- HAMLE 2: KONSÜLTASYON OLUŞTUR ---
  Future<String> createConsultation(Map<String, dynamic> medicalFormData) async {
    try {
      final response = await _dio.post(
        '/consultations',
        data: {'medicalFormData': medicalFormData},
      );
      // Gelen cevaptaki 'id'yi (consultationId) döndür
      return response.data['id'];
    } catch (e) {
      rethrow;
    }
  }

  // --- HAMLE 3: URL İSTE ---
  // Bu fonksiyon, dosya bilgilerini (FileInfoDto) ve consultationId'yi alır
  Future<List<dynamic>> requestUploadUrls(String consultationId, List<Map<String, dynamic>> filesInfo) async {
    try {
      final response = await _dio.post(
        '/consultations/request-upload-urls',
        data: {
          'consultationId': consultationId,
          'files': filesInfo, // [{'filename': ..., 'contentType': ..., 'angle_tag': ...}]
        },
      );
      // Gelen 'uploadTasks' listesini döndür
      return response.data['uploadTasks'];
    } catch (e) {
      rethrow;
    }
  }

  // --- HAMLE 4: DOSYAYI DO SPACES'E YÜKLE ---
  // Bu, bizim API'ye DEĞİL, DO Spaces'in verdiği URL'ye istek atar.
  Future<void> uploadFileToSpaces(String preSignedUrl, File file, String contentType) async {
    try {
      final fileBytes = await file.readAsBytes();

      await _dio.put(
        preSignedUrl, // API'den değil, DO'dan gelen tam URL
        data: Stream.fromIterable(fileBytes.map((e) => [e])), // Dosyanın ham baytları
        options: Options(
          headers: {
            // NestJS'e değil, S3'e dosya tipi ve uzunluğunu bildirmeliyiz
            'Content-Length': fileBytes.length,
            'Content-Type': contentType, // Bunu dinamik hale getirebiliriz
          },
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  // --- HAMLE 5: YÜKLEMEYİ ONAYLA ---
  Future<void> confirmUpload(String consultationId, List<Map<String, dynamic>> uploadedPhotos) async {
    try {
      await _dio.post(
        '/consultations/confirm-upload',
        data: {
          'consultationId': consultationId,
          'photos': uploadedPhotos, // [{'file_url': ..., 'angle_tag': ...}]
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  // --- YENİ METOT: KONSÜLTASYONLARIMI GETİR ---
Future<List<dynamic>> getMyConsultations() async {
  try {
    // GET isteği at (Header'a token otomatik eklenecek)
    final response = await _dio.get('/consultations');
    // Gelen listeyi (JSON) doğrudan BLoC'a döndür
    return response.data as List<dynamic>; 
  } catch (e) {
    rethrow;
  }
}
}