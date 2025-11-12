import 'dart:io'; // 'File' sınıfı için
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/consultation/bloc/consultation_event.dart';
import '/consultation/bloc/consultation_state.dart';
import '/services/api_service.dart';

class ConsultationBloc extends Bloc<ConsultationEvent, ConsultationState> {
  // Sadece ApiService'e ihtiyacımız var
  final ApiService _apiService;

  ConsultationBloc({required ApiService apiService})
      : _apiService = apiService,
        super(ConsultationInitial()) {
    // ConsultationSubmitted event'i gelince _onSubmitted fonksiyonunu çalıştır
    on<ConsultationSubmitted>(_onSubmitted);
  }

  // O 5 ADIMLIK KANSER TESTİNİN KOD HALİ
  Future<void> _onSubmitted(
    ConsultationSubmitted event,
    Emitter<ConsultationState> emit,
  ) async {
    try {
      // 1. ADIM: Konsültasyon kaydını oluştur
      emit(const ConsultationUploadInProgress(
        message: "Konsültasyon kaydı oluşturuluyor...",
        progress: 0.1,
      ));

      final consultationId = await _apiService.createConsultation(event.medicalFormData);

      // 2. ADIM: Yükleme URL'lerini iste
      emit(const ConsultationUploadInProgress(
        message: "Yükleme adresleri hazırlanıyor...",
        progress: 0.3,
      ));

      // API'ye göndereceğimiz dosya bilgilerini hazırla
      List<Map<String, dynamic>> filesInfo = [];
      for (int i = 0; i < event.photos.length; i++) {
        filesInfo.add({
          'filename': event.photos[i].name,
          'contentType': event.photos[i].mimeType ?? 'image/jpeg', // MIME tipi
          'angle_tag': event.angleTags[i], // Açı etiketi
        });
      }

      final uploadTasks = await _apiService.requestUploadUrls(consultationId, filesInfo);

      // 3. ADIM: Dosyaları DO Spaces'e (kovaya) yükle
      emit(ConsultationUploadInProgress(
        // YENİ: Başlangıç mesajı '0' olarak düzeltildi
        message: "Fotoğraflar yükleniyor (0/${uploadTasks.length})...",
        progress: 0.5,
      ));

      List<Future> uploadFutures = []; // Paralel yükleme için
      List<Map<String, dynamic>> confirmedPhotoData = []; // 4. Adım için veri topla

      // ==========================================
      // YENİ: Yarış Durumunu (Race Condition) önlemek için sayaç
      int completedUploads = 0;
      final int totalUploads = uploadTasks.length;
      // ==========================================

      for (int i = 0; i < uploadTasks.length; i++) {
        final task = uploadTasks[i];
        final photoRequest = filesInfo[i];
        final file = File(event.photos[i].path); // XFile'ı File'a dönüştür

        // Yükleme işlemini listeye ekle
        uploadFutures.add(
          _apiService.uploadFileToSpaces(
            task['preSignedUrl'],
            file,
            photoRequest['contentType'],
          ).then((_) {
            // Yükleme başarılı olursa, 4. adım için veriyi topla
            confirmedPhotoData.add({
              'file_url': task['finalUrl'],
              'angle_tag': task['angle_tag'],
            });

            // ==========================================
            // YENİ: Sayaç kullanarak emit et
            completedUploads++; // Sayacı artır
            
            // UI'a ilerlemeyi bildir (dinamik)
            emit(ConsultationUploadInProgress(
              // 'i+1' yerine SAYAÇTAKİ değeri kullan
              message: "Fotoğraflar yükleniyor ($completedUploads/$totalUploads)...",
              progress: 0.5 + (0.4 * (completedUploads / totalUploads)), // 0.5'ten 0.9'a
            ));
            // ==========================================
          }),
        );
      }

      // Tüm paralel yüklemelerin bitmesini bekle
      await Future.wait(uploadFutures);

      // 4. ADIM: Yüklemeyi Onayla (Veritabanına Yaz)
      emit(const ConsultationUploadInProgress(
        message: "Yükleme tamamlanıyor...",
        progress: 0.95,
      ));

      await _apiService.confirmUpload(consultationId, confirmedPhotoData);

      // 5. ADIM: Bitti!
      emit(ConsultationSuccess());
    } catch (e) {
      // Hata yönetimi
      if (e is DioException) {
        emit(ConsultationFailure("API Hatası: ${e.response?.data['message'] ?? e.message}"));
      } else {
        emit(ConsultationFailure("Bilinmeyen bir hata oluştu: ${e.toString()}"));
      }
    }
  }
}