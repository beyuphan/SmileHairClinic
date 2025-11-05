import 'package:equatable/equatable.dart';
import 'package:camera/camera.dart'; // 'camera' paketinden XFile'ı import et

abstract class ConsultationEvent extends Equatable {
  const ConsultationEvent();

  @override
  List<Object> get props => [];
}

// Yükleme akışını başlat
class ConsultationSubmitted extends ConsultationEvent {
  // 1. Kamera ile çekilen fotoğrafların listesi
  final List<XFile> photos;

  // 2. Bu fotoğrafların açı etiketleri (örn: 'front', 'top', 'donor')
  // (UI bu listeyi fotoğraflarla aynı sırada vermek zorunda)
  final List<String> angleTags;

  // 3. UI'daki ek form verisi (tıbbi notlar vb.)
  final Map<String, dynamic> medicalFormData;

  const ConsultationSubmitted({
    required this.photos,
    required this.angleTags,
    required this.medicalFormData,
  });

  @override
  List<Object> get props => [photos, angleTags, medicalFormData];
}