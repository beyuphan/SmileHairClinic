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

  const BookSlot({required this.slotId});

  @override
  List<Object> get props => [slotId];
}