import 'dart:async'; // Future.delayed için
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ========================================================================
// ==================== SES GERİ BİLDİRİMİ YARDIMCISI ====================
// ========================================================================

/// Ses geri bildirimi için yardımcı sınıf
class AudioFeedbackHelper {
 // YENİ: Player'ları görevlerine göre ayırdık
 final AudioPlayer _eventPlayer = AudioPlayer(); // Başarı, kayıp, deklanşör için
 final AudioPlayer _geigerPlayer = AudioPlayer(); // Sadece Geiger/Tick sesi için
 final FlutterTts _flutterTts = FlutterTts();

 bool _isSpeechEnabled = true;
 bool _isPlayingCountdown = false;

 AudioFeedbackHelper() {
  _initializeTts();
  // YENİ: Geiger player'ı döngüye hazırla (bu sesin kesilmemesi lazım)
  _geigerPlayer.setReleaseMode(ReleaseMode.stop);
 }

 void _initializeTts() async {
  await _flutterTts.setLanguage("tr-TR");
  await _flutterTts.setSpeechRate(0.6); // Anlaşılır hız
  await _flutterTts.setVolume(1.0);
  await _flutterTts.setPitch(1.0);
 }

 /// Ses geri bildirimini aç/kapat
 void toggleSpeech(bool enabled) {
  _isSpeechEnabled = enabled;
  if (!enabled) {
   stopAll();
  }
 }

 // ========== BİP SESLERİ (EVENT PLAYER) ==========

 /// Pozitif geri bildirim (Hizalama başarılı)
 Future<void> playAlignmentSuccess() async {
  try {
   await _eventPlayer.play(AssetSource('sounds/beep_success.mp3'));
  } catch (e) {
   print("Ses oynatma hatası (success): $e");
  }
 }

 /// Negatif geri bildirim (Hizalama kayboldu)
 Future<void> playAlignmentLost() async {
  try {
   await _eventPlayer.play(AssetSource('sounds/beep_warning.mp3'));
  } catch (e) {
   print("Ses oynatma hatası (lost): $e");
  }
 }

 /// Fotoğraf çekim sesi
 Future<void> playShutterSound() async {
  try {
   await _eventPlayer.play(AssetSource('sounds/camera_shutter.mp3'));
  } catch (e) {
   print("Ses oynatma hatası (shutter): $e");
  }
 }

 // ========== BİP SESİ (GEIGER/TICK PLAYER) ==========

 /// Geri sayım VEYA Geiger sayacı sesi
 /// BU ASLA KESİLMEMELİ (TTS konuşurken bile)
 Future<void> playTick() async {
  try {
   await _geigerPlayer.play(AssetSource('sounds/beep_tick.mp3'));
  } catch (e) {
   print("Ses oynatma hatası (tick): $e");
  }
 }

 // ========== SESLİ TALİMATLAR (TTS) ==========

 /// Adım bazlı yönlendirme (Kısa)
 Future<void> speakStepInstruction(String stepTag) async {
  if (!_isSpeechEnabled) return;
  String instruction = "";
  switch (stepTag) {
   case 'front': instruction = "Kameraya bakın ve silueti doldurun."; break;
   case 'top': instruction = "Cihazı düz tutup üst kısmı çekin."; break;
   case 'left_side': instruction = "Sağa dönüp sol profili çekin."; break;
   case 'right_side': instruction = "Sola dönüp sağ profili çekin."; break;
   case 'donor_area_back': instruction = "Cihazı eğip arka kısmı çekin."; break;
  }
  if (instruction.isNotEmpty) {
   await _flutterTts.stop();
   await _flutterTts.speak(instruction);
  }
 }

 /// DEĞİŞİKLİK: Hizalama sağlandığında artık konuşma.
 /// Bip sesi yeterli.
 Future<void> speakAlignmentSuccess() async {
  return; // KALDIRILDI: await _flutterTts.speak("Harika, bekleyin.");
 }

 /// Yüz bulunamadıysa (Kısa)
 Future<void> speakFaceNotFound() async {
  if (!_isSpeechEnabled) return;
  await _flutterTts.stop();
  await _flutterTts.speak("Yüzünüz görünmüyor.");
 }
 
 /// YENİ: Akıllı sensör uyarıları veya özel mesajlar
 Future<void> speakCustom(String message) async {
  if (!_isSpeechEnabled) return;
  await _flutterTts.stop();
  await _flutterTts.speak(message);
 }


 /// Geri sayım (Sessiz, Sadece Bip-Bip-Bip)
 Future<void> speakCountdown() async {
  if (_isPlayingCountdown || !_isSpeechEnabled) return;

  _isPlayingCountdown = true;
  await _flutterTts.stop(); // Konuşma olmadığından emin ol

  try {
   await Future.delayed(const Duration(milliseconds: 900));
   if (!_isPlayingCountdown) throw Exception("Countdown cancelled");
   await playTick(); // Geiger player üzerinden çal

   await Future.delayed(const Duration(milliseconds: 900));
   if (!_isPlayingCountdown) throw Exception("Countdown cancelled");
   await playTick();

   await Future.delayed(const Duration(milliseconds: 900));
   if (!_isPlayingCountdown) throw Exception("Countdown cancelled");
   await playTick();

  } catch (e) {
   print("Geri sayım iptal edildi: $e");
  } finally {
   _isPlayingCountdown = false;
  }
 }

 /// DEĞİŞİKLİK: Fotoğraf çekildiğinde sadece deklanşör sesi çal.
 Future<void> speakPhotoTaken() async {
  await playShutterSound(); // Deklanşör sesi her zaman çalsın
  // KALDIRILDI: "Tamamlandı" konuşması kaldırıldı.
  // if (!_isSpeechEnabled) return;
  // await Future.delayed(const Duration(milliseconds: 300));
  // await _flutterTts.stop();
  // await _flutterTts.speak("Tamamlandı.");
 }

 /// Tüm sesleri durdur
 Future<void> stopAll() async {
  _isPlayingCountdown = false;
  await _eventPlayer.stop();
  await _geigerPlayer.stop(); // YENİ: Geiger player'ı da durdur
  await _flutterTts.stop();
 }

 /// Kaynakları temizle
 void dispose() {
  _eventPlayer.dispose();
  _geigerPlayer.dispose(); // YENİ: Geiger player'ı da dispose et
  _flutterTts.stop();
 }
}