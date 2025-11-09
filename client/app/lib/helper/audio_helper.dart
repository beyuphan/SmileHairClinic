import 'dart:async'; // Future.delayed için
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ========================================================================
// ==================== SES GERİ BİLDİRİMİ YARDIMCISI ====================
// ========================================================================

/// Ses geri bildirimi için yardımcı sınıf
class AudioFeedbackHelper {
 final AudioPlayer _audioPlayer = AudioPlayer();
 final FlutterTts _flutterTts = FlutterTts();
 
 bool _isSpeechEnabled = true; // Kullanıcı sesli talimatı kapatabilir
 bool _isPlayingCountdown = false;

 AudioFeedbackHelper() {
 _initializeTts();
 }

 void _initializeTts() async {
  await _flutterTts.setLanguage("tr-TR");
    // Not: Konuşma hızı 1.0 çok hızlı olabilir, 0.5-0.6 daha anlaşılır olabilir.
  await _flutterTts.setSpeechRate(1.0); 
  await _flutterTts.setVolume(1.0);
  await _flutterTts.setPitch(1.0);
 }

 /// Ses geri bildirimini aç/kapat
 void toggleSpeech(bool enabled) {
  _isSpeechEnabled = enabled;
    if (!enabled) {
      stopAll(); // Ses kapatılırsa, o an konuşanı da sustur
    }
 }

 // ========== BİP SESLERİ ==========
 
 /// Pozitif geri bildirim (Hizalama başarılı)
 Future<void> playAlignmentSuccess() async {
    // Sadece bip sesleri 'speechEnabled'den bağımsız olabilir,
    // ya da bunu da _isSpeechEnabled'e bağlayabilirsin.
    // Şimdilik bağımsız bırakıyorum.
  try {
   await _audioPlayer.play(AssetSource('sounds/beep_success.mp3'));
  } catch (e) {
   print("Ses oynatma hatası: $e");
  }
 }

 /// Negatif geri bildirim (Hizalama kayboldu)
 Future<void> playAlignmentLost() async {
  try {
   await _audioPlayer.play(AssetSource('sounds/beep_warning.mp3'));
  } catch (e) {
   print("Ses oynatma hatası: $e");
  }
 }

 /// Geri sayım sesi (3-2-1)
 Future<void> playCountdownTick() async {
  if (_isPlayingCountdown) return;
  try {
   await _audioPlayer.play(AssetSource('sounds/beep_tick.mp3'));
  } catch (e) {
   print("Ses oynatma hatası: $e");
  }
 }

 /// Fotoğraf çekim sesi
 Future<void> playShutterSound() async {
  try {
   await _audioPlayer.play(AssetSource('sounds/camera_shutter.mp3'));
  } catch (e) {
   print("Ses oynatma hatası: $e");
  }
 }

 // ========== SESLİ TALİMATLAR (TTS) ==========

 /// Adım bazlı yönlendirme
 Future<void> speakStepInstruction(String stepTag) async {
  if (!_isSpeechEnabled) return;

  String instruction = "";
  switch (stepTag) {
   case 'front':
    instruction = "Lütfen kameraya doğrudan bakın ve siluetin içini doldurun";
    break;
   case 'top':
    instruction = "Cihazı yere paralel tutun ve başınızın üstünü gösterin";
    break;
   case 'left_side':
    instruction = "Başınızı sağa çevirin ve sol yanınızı gösterin";
    break;
   case 'right_side':
    instruction = "Başınızı sola çevirin ve sağ yanınızı gösterin";
    break;
   case 'donor_area_back':
    instruction = "Cihazı aşağı eğin ve başınızın arkasını gösterin";
    break;
  }

  if (instruction.isNotEmpty) {
      await _flutterTts.stop(); // Önceki konuşmayı kes
   await _flutterTts.speak(instruction);
  }
 }

 /// Hizalama sağlandığında
 Future<void> speakAlignmentSuccess() async {
  if (!_isSpeechEnabled) return;
    await _flutterTts.stop();
  await _flutterTts.speak("Harika! Sabit durun");
 }

 /// Sensör açısı yanlışsa
 Future<void> speakAngleWarning(String stepTag) async {
  if (!_isSpeechEnabled) return;

    await _flutterTts.stop();
  if (stepTag == 'top') {
   await _flutterTts.speak("Cihazı daha düz tutun");
  } else if (stepTag == 'donor_area_back') {
   await _flutterTts.speak("Cihazı daha aşağı eğin");
  }
 }

 /// Özel mesaj söyle (doluluk uyarıları için)
 Future<void> speakCustom(String message) async {
  if (!_isSpeechEnabled) return;
    await _flutterTts.stop();
  await _flutterTts.speak(message);
 }

 /// Yüz bulunamadıysa
 Future<void> speakFaceNotFound() async {
  if (!_isSpeechEnabled) return;
    await _flutterTts.stop();
  await _flutterTts.speak("Yüzünüz görünmüyor");
 }

 /// Geri sayım (3-2-1)
 Future<void> speakCountdown() async {
  if (!_isSpeechEnabled || _isPlayingCountdown) return;
  
  _isPlayingCountdown = true;
    await _flutterTts.stop();
  await _flutterTts.speak("3");
  await Future.delayed(const Duration(milliseconds: 900));
  await playCountdownTick();
  
    if (!_isSpeechEnabled) { _isPlayingCountdown = false; return; } // Geri sayımda ses kapatılırsa
  await _flutterTts.speak("2");
  await Future.delayed(const Duration(milliseconds: 900));
  await playCountdownTick();
  
    if (!_isSpeechEnabled) { _isPlayingCountdown = false; return; }
  await _flutterTts.speak("1");
  await Future.delayed(const Duration(milliseconds: 900));
  await playCountdownTick();
  
  _isPlayingCountdown = false;
 }

 /// Fotoğraf çekildiğinde
 Future<void> speakPhotoTaken() async {
  await playShutterSound(); // Deklanşör sesi her zaman çalsın
  if (!_isSpeechEnabled) return; // Ama konuşma yapmasın
  await Future.delayed(const Duration(milliseconds: 500));
    await _flutterTts.stop();
  await _flutterTts.speak("Çekim tamamlandı");
 }

 /// Tüm sesleri durdur
 Future<void> stopAll() async {
  await _audioPlayer.stop();
  await _flutterTts.stop();
  _isPlayingCountdown = false;
 }

 /// Kaynakları temizle
 void dispose() {
  _audioPlayer.dispose();
  _flutterTts.stop();
 }
}