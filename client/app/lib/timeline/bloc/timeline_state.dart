import 'package:equatable/equatable.dart';

abstract class TimelineState extends Equatable {
  const TimelineState();
  @override
  List<Object> get props => [];
}

class TimelineInitial extends TimelineState {}

class TimelineLoading extends TimelineState {}

class TimelineFailure extends TimelineState {
  final String error;
  const TimelineFailure(this.error);
  @override
  List<Object> get props => [error];
}

// Görevler başarıyla çekildi (Liste artık elimizde)
class TimelineLoaded extends TimelineState {
  final List<dynamic> events; // Sunucudan gelen ham JSON listesi
  const TimelineLoaded(this.events);
  @override
  List<Object> get props => [events];
}