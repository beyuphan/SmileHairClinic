// client/app/lib/services/api_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'storage_service.dart'; // <-- DİKKAT: Artık FlutterSecureStorage değil, kendi servisimizi import ediyoruz

class ApiService {
  final Dio _dio;
  final SecureStorageService _storageService; // <-- DEĞİŞİKLİK 1

  static const String _baseUrl = "http://192.168.1.25:3000"; // <-- BURAYI KENDİ IP'N İLE GÜNCELLE

  // --- DEĞİŞİKLİK 2: Artık 'SecureStorageService'i parametre olarak alıyor ---
  ApiService({required SecureStorageService storageService})
      : _dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          )
        ),
        _storageService = storageService { // <-- DEĞİŞİKLİK 3

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // --- DEĞİŞİKLİK 4: Token'ı artık 'storageService'ten okuyoruz ---
          final token = await _storageService.getToken();

         if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            print("🟢 API İsteği: ${options.path} (Token Eklendi)");
          } else {
            print("🔴 API İsteği: ${options.path} (TOKEN YOK!)");
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          print("🔥 API Hatası: ${e.response?.statusCode} - ${e.message}");
          print("🔥 API Hatası Mesaj: ${e.response?.data}"); // <-- BU SATIR ÇOK ÖNEMLİ
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
      return response.data['accessToken'];
    } catch (e) {
      rethrow; 
    }
  }

  // --- HAMLE 2: KONSÜLTASYON OLUŞTUR ---
  Future<String> createConsultation(Map<String, dynamic> medicalFormData) async {
    try {
      final response = await _dio.post(
        '/consultations',
        data: {'medicalFormData': medicalFormData},
      );
      return response.data['id'];
    } catch (e) {
      rethrow;
    }
  }

  // --- HAMLE 3: URL İSTE ---
  Future<List<dynamic>> requestUploadUrls(String consultationId, List<Map<String, dynamic>> filesInfo) async {
    try {
      final response = await _dio.post(
        '/consultations/request-upload-urls',
        data: {
          'consultationId': consultationId,
          'files': filesInfo,
        },
      );
      return response.data['uploadTasks'];
    } catch (e) {
      rethrow;
    }
  }

  // --- HAMLE 4: DOSYAYI DO SPACES'E YÜKLE ---
  Future<void> uploadFileToSpaces(String preSignedUrl, File file, String contentType) async {
    try {
      final int fileLength = await file.length();
      final Stream<List<int>> fileStream = file.openRead();

      await _dio.put(
        preSignedUrl, 
        data: fileStream, 
        options: Options(
          headers: {
            'Content-Length': fileLength, 
            'Content-Type': contentType,
            'Connection': 'keep-alive',
          },
        ),
      );
    } catch (e) {
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
          'photos': uploadedPhotos,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  // --- KONSÜLTASYONLARIMI GETİR ---
  Future<List<dynamic>> getMyConsultations() async {
    try {
      final response = await _dio.get('/consultations');
      return response.data as List<dynamic>; 
    } catch (e) {
      rethrow;
    }
  }

  // --- DETAYLARI GETİR ---
  Future<Map<String, dynamic>> getConsultationDetails(String consultationId) async {
    try {
      final response = await _dio.get('/consultations/$consultationId');
      return response.data as Map<String, dynamic>; 
    } catch (e) {
      rethrow;
    }
  }

  // --- TİMELİNE GETİR ---
  Future<List<dynamic>> getMyTimeline() async {
    try {
      final response = await _dio.get('/timeline');
      return response.data as List<dynamic>; 
    } catch (e) {
      rethrow;
    }
  }

  // --- CHAT GEÇMİŞİ ---
  Future<List<dynamic>> getChatHistory() async {
    try {
      final response = await _dio.get('/chat/history/me');
      return response.data as List<dynamic>; 
    } catch (e) {
      rethrow;
    }
  }

  // --- BOŞ SLOTLARI AL ---
  Future<List<dynamic>> getAvailableSlots() async {
    try {
      final response = await _dio.get('/appointments/available-slots');
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // --- SLOT REZERVE ET ---
  Future<void> bookSlot(String slotId) async {
    try {
      await _dio.post(
        '/appointments/book-slot',
        data: {
          'slotId': slotId,
        },
      );
    } catch (e) {
      rethrow;
    }
  }
}