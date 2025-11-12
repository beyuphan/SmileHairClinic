import 'package:flutter_bloc/flutter_bloc.dart';
import '/timeline/bloc/timeline_event.dart';
import '/timeline/bloc/timeline_state.dart';
import '/services/api_service.dart'; // ApiService'i import et

class TimelineBloc extends Bloc<TimelineEvent, TimelineState> {
  final ApiService _apiService;

  TimelineBloc({required ApiService apiService})
      : _apiService = apiService,
        super(TimelineInitial()) {
          
    // FetchTimeline event'i gelince _onFetchTimeline fonksiyonunu çalıştır
    on<FetchTimeline>(_onFetchTimeline);
  }

  Future<void> _onFetchTimeline(
    FetchTimeline event,
    Emitter<TimelineState> emit,
  ) async {
    emit(TimelineLoading());
    try {
      // 1. ApiService'teki yeni metodu çağır
      final events = await _apiService.getMyTimeline();
      
      // 2. Başarılı durumu (State) ve gelen listeyi UI'a gönder
      emit(TimelineLoaded(events));
      
    } catch (e) {
      // 3. Hata olursa UI'a bildir
      emit(TimelineFailure(e.toString()));
    }
  }
}