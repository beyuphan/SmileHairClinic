// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginScreenTitle => 'Sign In';

  @override
  String get loginButton => 'Login';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get errorLoginFailed => 'Invalid email or password.';

  @override
  String get errorEmailFormat => 'Invalid email format.';

  @override
  String errorServerConnection(Object errorMessage) {
    return 'Could not connect to the server: $errorMessage';
  }

  @override
  String errorUnknown(Object errorMessage) {
    return 'An unknown error occurred: $errorMessage';
  }

  @override
  String get homeScreenTitle => 'Home';

  @override
  String get logoutButton => 'Logout';

  @override
  String get startConsultationButton => 'Start New Consultation';

  @override
  String get myConsultationsButton => 'My Consultations';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardNewConsultationTitle => 'Start a New Consultation';

  @override
  String get dashboardNewConsultationSubtitle =>
      'Upload your photos and get a review from our doctors.';

  @override
  String get navbarHome => 'Home';

  @override
  String get navbarConsultations => 'Consultations';

  @override
  String get navbarTimeline => 'Timeline';

  @override
  String get navbarProfile => 'Profile';
}
