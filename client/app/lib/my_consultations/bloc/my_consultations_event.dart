import 'package:equatable/equatable.dart';

abstract class MyConsultationsEvent extends Equatable {
  const MyConsultationsEvent();
  @override
  List<Object> get props => [];
}

// Ekran açıldığında veriyi çekmek için
class FetchMyConsultations extends MyConsultationsEvent {}