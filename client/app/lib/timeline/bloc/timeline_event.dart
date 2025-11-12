import 'package:equatable/equatable.dart';

abstract class TimelineEvent extends Equatable {
  const TimelineEvent();
  @override
  List<Object> get props => [];
}

// Ekran açıldığında "Yolculuk" görevlerini çekmek için
class FetchTimeline extends TimelineEvent {}