import 'package:equatable/equatable.dart';

abstract class AppointmentState extends Equatable {
  const AppointmentState();
  @override
  List<Object> get props => [];
}

class AppointmentInitial extends AppointmentState {}

class AppointmentSlotsLoading extends AppointmentState {}

class AppointmentSlotsLoaded extends AppointmentState {
  // Backend'den gelen slot listesi (örn: [{'id': '...', 'dateTime': '...'}])
  final List<dynamic> slots;
  const AppointmentSlotsLoaded(this.slots);
  @override
  List<Object> get props => [slots];
}

class AppointmentSlotsFailure extends AppointmentState {
  final String error;
  const AppointmentSlotsFailure(this.error);
  @override
  List<Object> get props => [error];
}

// Kullanıcı "Seç" butonuna bastı, bekliyor
class AppointmentBookingInProgress extends AppointmentState {}

// Başarıyla rezerve edildi
class AppointmentBookingSuccess extends AppointmentState {}

// Rezervasyon patladı
class AppointmentBookingFailure extends AppointmentState {
  final String error;
  const AppointmentBookingFailure(this.error);
  @override
  List<Object> get props => [error];
}