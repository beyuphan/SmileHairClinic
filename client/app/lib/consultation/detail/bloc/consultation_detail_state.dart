import 'package:equatable/equatable.dart';

abstract class ConsultationDetailState extends Equatable {
  const ConsultationDetailState();
  @override
  List<Object> get props => [];
}

class ConsultationDetailInitial extends ConsultationDetailState {}

class ConsultationDetailLoading extends ConsultationDetailState {}

class ConsultationDetailFailure extends ConsultationDetailState {
  final String error;
  const ConsultationDetailFailure(this.error);
  @override
  List<Object> get props => [error];
}

// Veri başarıyla çekildi (Tüm 6 fotoğraf ve detaylar elimizde)
class ConsultationDetailLoaded extends ConsultationDetailState {
  final Map<String, dynamic> consultation; // Sunucudan gelen ham JSON
  const ConsultationDetailLoaded(this.consultation);
  @override
  List<Object> get props => [consultation];
}