import 'package:flutter_bloc/flutter_bloc.dart';
import '/services/api_service.dart';
import 'appointment_event.dart';
import 'appointment_state.dart';

class AppointmentBloc extends Bloc<AppointmentEvent, AppointmentState> {
  final ApiService _apiService;

  AppointmentBloc({required ApiService apiService})
      : _apiService = apiService,
        super(AppointmentInitial()) {
    
    // Event'lere göre fonksiyonları bağla
    on<FetchAvailableSlots>(_onFetchAvailableSlots);
    on<BookSlot>(_onBookSlot);
  }

  // Boş slotları çekme
  Future<void> _onFetchAvailableSlots(
    FetchAvailableSlots event,
    Emitter<AppointmentState> emit,
  ) async {
    emit(AppointmentSlotsLoading());
    try {
      final slots = await _apiService.getAvailableSlots();
      emit(AppointmentSlotsLoaded(slots));
    } catch (e) {
      emit(AppointmentSlotsFailure(e.toString()));
    }
  }

  // Seçilen slotu rezerve etme
  Future<void> _onBookSlot(
    BookSlot event,
    Emitter<AppointmentState> emit,
  ) async {
    emit(AppointmentBookingInProgress());
    try {
      await _apiService.bookSlot(event.slotId, event.consultationId);
      emit(AppointmentBookingSuccess());
    } catch (e) {
      emit(AppointmentBookingFailure(e.toString()));
    }
  }
}