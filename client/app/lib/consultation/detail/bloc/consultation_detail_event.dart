import 'package:equatable/equatable.dart';

abstract class ConsultationDetailEvent extends Equatable {
  const ConsultationDetailEvent();
  @override
  List<Object> get props => [];
}

// Ekran açıldığında detayı çekmek için
class FetchConsultationDetail extends ConsultationDetailEvent {
  final String consultationId;
  const FetchConsultationDetail(this.consultationId);

  @override
  List<Object> get props => [consultationId];
}