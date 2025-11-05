import 'package:flutter_bloc/flutter_bloc.dart';
import '/my_consultations/bloc/my_consultations_event.dart';
import '/my_consultations/bloc/my_consultations_state.dart';
import '/services/api_service.dart';

class MyConsultationsBloc extends Bloc<MyConsultationsEvent, MyConsultationsState> {
  final ApiService _apiService;

  MyConsultationsBloc({required ApiService apiService})
      : _apiService = apiService,
        super(MyConsultationsInitial()) {

    on<FetchMyConsultations>(_onFetchMyConsultations);
  }

  Future<void> _onFetchMyConsultations(
  FetchMyConsultations event,
  Emitter<MyConsultationsState> emit,
) async {
  emit(MyConsultationsLoading());
  try {
    // BASİT VE ESKİ LOGİK: Sadece bir kez dener
    final consultations = await _apiService.getMyConsultations();
    emit(MyConsultationsLoaded(consultations));
  } catch (e) {
    // Hata olursa, direkt göster (Tekrar deneme yok)
    emit(MyConsultationsFailure(e.toString()));
  }
  }
}