import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  // Android Emülatör için 'localhost' 10.0.2.2'dir.
  // iOS Simülatör veya gerçek cihaz için local IP'ni (örn: 192.168.1.10) yazmalısın.
  static const String _baseUrl = "http://192.168.1.25:3000";

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
    // 1. Önce dosyanın bayt uzunluğunu al (header için gerekli)
    final int fileLength = await file.length();
    
    // 2. Dosyayı hafızaya okumadan, doğrudan bir okuma stream'i aç
    final Stream<List<int>> fileStream = file.openRead();

    await _dio.put(
      preSignedUrl, // API'den değil, DO'dan gelen tam URL
      data: fileStream, // 3. Veri olarak stream'in kendisini yolla
      options: Options(
        headers: {
          // 4. Content-Length'i mutlaka S3'e bildirmeliyiz
          'Content-Length': fileLength, 
          'Content-Type': contentType,
          'Connection': 'keep-alive', // Bağlantıyı canlı tut
        },
      ),
    );
  } catch (e) {
    // Hata durumunda daha detaylı log ver
    print("uploadFileToSpaces Hatası: $e");
    if (e is DioException) {
      print("Dio Hatası Detayı (S3): ${e.response?.data}");
    }
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

Future<Map<String, dynamic>> getConsultationDetails(String consultationId) async {
  try {
    // GET isteği at (örn: /consultations/abc-123)
    // Header'a token otomatik eklenecek
    final response = await _dio.get('/consultations/$consultationId');

    // Gelen JSON objesini (Map) doğrudan BLoC'a döndür
    return response.data as Map<String, dynamic>; 
  } catch (e) {
    rethrow;
  }
}

Future<List<dynamic>> getMyTimeline() async {
  try {
    final response = await _dio.get('/timeline');
    return response.data as List<dynamic>; 
  } catch (e) {
    rethrow;
  }
}

Future<List<dynamic>> getChatHistory(String consultationId) async {
  try {
    final response = await _dio.get('/chat/history/$consultationId');
    return response.data as List<dynamic>; 
  } catch (e) {
    rethrow;
  }
}
}