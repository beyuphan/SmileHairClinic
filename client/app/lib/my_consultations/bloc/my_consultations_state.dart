import 'package:equatable/equatable.dart';

abstract class MyConsultationsState extends Equatable {
  const MyConsultationsState();
  @override
  List<Object> get props => [];
}

class MyConsultationsInitial extends MyConsultationsState {}

class MyConsultationsLoading extends MyConsultationsState {}

class MyConsultationsFailure extends MyConsultationsState {
  final String error;
  const MyConsultationsFailure(this.error);
  @override
  List<Object> get props => [error];
}

// Veri başarıyla çekildi (Liste artık elimizde)
class MyConsultationsLoaded extends MyConsultationsState {
  final List<dynamic> consultations; // Sunucudan gelen ham liste
  const MyConsultationsLoaded(this.consultations);
  @override
  List<Object> get props => [consultations];
}