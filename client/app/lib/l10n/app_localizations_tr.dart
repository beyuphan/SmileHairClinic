// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get loginScreenTitle => 'Giriş Yap';

  @override
  String get loginButton => 'Giriş Yap';

  @override
  String get emailLabel => 'E-posta';

  @override
  String get passwordLabel => 'Şifre';

  @override
  String get errorLoginFailed => 'Email veya şifre hatalı.';

  @override
  String get errorEmailFormat => 'Geçersiz email formatı.';

  @override
  String errorServerConnection(Object errorMessage) {
    return 'Sunucuya bağlanılamadı: $errorMessage';
  }

  @override
  String errorUnknown(Object errorMessage) {
    return 'Bilinmeyen bir hata oluştu: $errorMessage';
  }

  @override
  String get homeScreenTitle => 'Ana Sayfa';

  @override
  String get logoutButton => 'Çıkış Yap';

  @override
  String get startConsultationButton => 'Yeni Konsültasyon Başlat';

  @override
  String get myConsultationsButton => 'Geçmiş Konsültasyonlarım';

  @override
  String get dashboardTitle => 'Ana Sayfa';

  @override
  String get dashboardNewConsultationTitle => 'Yeni Konsültasyon Başlat';

  @override
  String get dashboardNewConsultationSubtitle =>
      'Fotoğraflarınızı yükleyin ve doktorlarımızdan değerlendirme alın.';

  @override
  String get navbarHome => 'Ana Sayfa';

  @override
  String get navbarConsultations => 'Görüşmeler';

  @override
  String get navbarTimeline => 'Süreç';

  @override
  String get navbarProfile => 'Profil';
}
