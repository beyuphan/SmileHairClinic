import 'package:equatable/equatable.dart';

abstract class AppointmentEvent extends Equatable {
  const AppointmentEvent();
  @override
  List<Object> get props => [];
}

// Ekran açılınca boş slotları çek
class FetchAvailableSlots extends AppointmentEvent {}

// Kullanıcı bir slota tıklayınca
class BookSlot extends AppointmentEvent {
  final String slotId;
  final String consultationId;

  const BookSlot({required this.slotId, required this.consultationId});

  @override
  List<Object> get props => [slotId, consultationId];
}