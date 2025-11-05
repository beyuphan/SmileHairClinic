import 'package:equatable/equatable.dart';

abstract class ConsultationState extends Equatable {
  const ConsultationState();

  @override
  List<Object> get props => [];
}

// Başlangıç durumu (Form hazır)
class ConsultationInitial extends ConsultationState {}

// Yükleme süreci başladı (O 5 adımlı akış)
class ConsultationUploadInProgress extends ConsultationState {
  // UI'a "Yükleniyor (1/5)..." gibi bir mesaj vermek için
  final String message;
  // UI'a 0.0 ile 1.0 arasında bir ilerleme (progress) vermek için
  final double progress;

  const ConsultationUploadInProgress({
    required this.message,
    required this.progress,
  });

  @override
  List<Object> get props => [message, progress];
}

// Akış başarıyla tamamlandı (UI, 'Başarılı' ekranına yönlendirebilir)
class ConsultationSuccess extends ConsultationState {}

// Akışın herhangi bir adımında hata oluştu
class ConsultationFailure extends ConsultationState {
  final String error;

  const ConsultationFailure(this.error);

  @override
  List<Object> get props => [error];
}