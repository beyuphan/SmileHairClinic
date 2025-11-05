import 'package:flutter_bloc/flutter_bloc.dart';
import '/consultation/detail/bloc/consultation_detail_event.dart';
import '/consultation/detail/bloc/consultation_detail_state.dart';
import '/services/api_service.dart';

class ConsultationDetailBloc extends Bloc<ConsultationDetailEvent, ConsultationDetailState> {
  final ApiService _apiService;

  ConsultationDetailBloc({required ApiService apiService})
      : _apiService = apiService,
        super(ConsultationDetailInitial()) {

    on<FetchConsultationDetail>(_onFetchConsultationDetail);
  }

  Future<void> _onFetchConsultationDetail(
    FetchConsultationDetail event,
    Emitter<ConsultationDetailState> emit,
  ) async {
    emit(ConsultationDetailLoading());
    try {
      // ApiService'teki yeni metodu çağır
      final consultation = await _apiService.getConsultationDetails(event.consultationId);
      emit(ConsultationDetailLoaded(consultation));
    } catch (e) {
      emit(ConsultationDetailFailure(e.toString()));
    }
  }
}