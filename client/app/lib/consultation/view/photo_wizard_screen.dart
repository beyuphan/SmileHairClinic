import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:sensors_plus/sensors_plus.dart';

import '/consultation/bloc/consultation_bloc.dart';
import '/consultation/bloc/consultation_event.dart';
import '/consultation/bloc/consultation_state.dart';
import '/services/api_service.dart';
import '/helper/audio_helper.dart';

class PhotoWizardScreen extends StatelessWidget {
 const PhotoWizardScreen({super.key});

 @override
 Widget build(BuildContext context) {
  return BlocProvider(
   create: (context) => ConsultationBloc(
    apiService: context.read<ApiService>(),
   ),
   child: const _PhotoWizardView(),
  );
 }
}

class _PhotoWizardView extends StatefulWidget {
 const _PhotoWizardView();

 @override
 State<_PhotoWizardView> createState() => _PhotoWizardViewState();
}

class _PhotoWizardViewState extends State<_PhotoWizardView> {
 late PageController _pageController;
 CameraController? _cameraController;
 late SelfieSegmenter _selfieSegmenter;
 late FaceDetector _faceDetector;

 bool _isDetecting = false;
 Timer? _autoCaptureTimer;
 bool _isFaceAligned = false;

 final List<XFile> _takenPhotos = [];

 final List<Map<String, String>> _steps = [
  {'tag': 'front', 'label': 'Ön Görünüm'},
  {'tag': 'top', 'label': 'Üst Görünüm'},
  {'tag': 'left_side', 'label': 'Sol Yan'},
  {'tag': 'right_side', 'label': 'Sağ Yan'},
  {'tag': 'donor_area_back', 'label': 'Donör Bölgesi (Arka)'},
 ];

 int get _totalSteps => _steps.length + 1;
 int _currentPage = 0;
 bool _isTakingPicture = false;

 final Map<String, Size> _overlayOriginalSizes = {};
 final Map<String, List<Point<int>>> _overlaySampledPoints = {};
 bool _areMasksLoaded = false;
 static const int _maskSamplingRate = 20;

 List<CameraDescription> _availableCameras = [];
 CameraLensDirection _selectedLensDirection = CameraLensDirection.front;

 StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
 double _devicePitch = 0.0;
 double _deviceRoll = 0.0;
 bool _isDeviceAngleCorrect = false;

 late AudioFeedbackHelper _audioHelper;
 bool _hasSpokenInstructionForCurrentStep = false;
 bool _isSpeechEnabled = true;
 DateTime? _lastWarningTime; // TTS spam koruması

 // YENİ: Geiger/Bip sesi yönetimi
 DateTime? _lastProgressBeepTime;
 // KALDIRILDI: _isSpeakingWarning bayrağı kaldırıldı, artık gerek yok.


 @override
 void initState() {
  super.initState();
  _pageController = PageController();

  _selfieSegmenter = SelfieSegmenter(
   mode: SegmenterMode.stream,
   enableRawSizeMask: true,
  );

  final faceOptions = FaceDetectorOptions(
   performanceMode: FaceDetectorMode.accurate,
   enableClassification: true,
  );
  _faceDetector = FaceDetector(options: faceOptions);

  _audioHelper = AudioFeedbackHelper();

  _loadOverlayMasksAndInitializeCamera();
  _startAccelerometerListener();
 }

 
 void _startAccelerometerListener() {
  _accelerometerSubscription = accelerometerEventStream(
   samplingPeriod: const Duration(milliseconds: 200),
  ).listen((AccelerometerEvent event) {
   if (!mounted) return;

   final double x = event.x;
   final double y = event.y;
   final double z = event.z;

   final double pitch = atan2(y, sqrt(x * x + z * z)) * (180 / pi);
   final double roll = atan2(x, sqrt(y * y + z * z)) * (180 / pi);

   setState(() {
    _devicePitch = pitch;
    _deviceRoll = roll;
    _checkDeviceAngle();
   });
  });
 }

 void _checkDeviceAngle() {
  if (_currentPage >= _steps.length) {
   _isDeviceAngleCorrect = true;
   return;
  }
  final String currentStepTag = _steps[_currentPage]['tag']!;
  bool angleOk = false;

  if (currentStepTag == 'top') {
   angleOk = _devicePitch.abs() < 25 && _deviceRoll.abs() < 15;
  } else if (currentStepTag == 'donor_area_back') {
   angleOk = (_devicePitch >= -50 && _devicePitch <= -25) && _deviceRoll.abs() < 15;
  } else {
   angleOk = true;
  }

  _isDeviceAngleCorrect = angleOk;
 }

 Future<void> _loadOverlayMasksAndInitializeCamera() async {
  try {
   _availableCameras = await availableCameras();
   if (_availableCameras.isEmpty) {
    throw Exception("Cihazda kamera bulunamadı.");
   }
   if (!_availableCameras.any((cam) => cam.lensDirection == _selectedLensDirection)) {
    _selectedLensDirection = _availableCameras.first.lensDirection;
   }

   for (final step in _steps) {
    final String tag = step['tag']!;
    await _loadOverlayMask(tag);
   }
   if (mounted) {
    setState(() => _areMasksLoaded = true);
    _initializeCamera();

    Future.delayed(const Duration(seconds: 2), () {
     if (mounted && _currentPage < _steps.length && !_hasSpokenInstructionForCurrentStep) {
      _audioHelper.speakStepInstruction(_steps[_currentPage]['tag']!);
      _hasSpokenInstructionForCurrentStep = true;
     }
    });
   }
  } catch (e) {
   print("Maske yükleme hatası: $e");
   if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(content: Text('Overlay maskeleri yüklenemedi: $e'), backgroundColor: Colors.red),
    );
   }
  }
 }

 Future<void> _loadOverlayMask(String tag) async {
  final String assetPath = 'assets/overlays/$tag.png';
  final ByteData data = await rootBundle.load(assetPath);
  final img.Image? pngImage = img.decodePng(data.buffer.asUint8List());

  if (pngImage == null) {
   throw Exception('$assetPath yüklenemedi veya bozuk.');
  }

  _overlayOriginalSizes[tag] = Size(pngImage.width.toDouble(), pngImage.height.toDouble());
  final List<Point<int>> sampledPoints = [];

  for (int y = 0; y < pngImage.height; y += _maskSamplingRate) {
   for (int x = 0; x < pngImage.width; x += _maskSamplingRate) {
    final pixel = pngImage.getPixel(x, y);
    if (pixel.a > 128) {
     sampledPoints.add(Point(x, y));
    }
   }
  }
  _overlaySampledPoints[tag] = sampledPoints;
 }

 Future<void> _initializeCamera() async {
  try {
   final CameraDescription cameraDescription = _availableCameras.firstWhere(
    (camera) => camera.lensDirection == _selectedLensDirection,
    orElse: () => _availableCameras.first,
   );

   await _cameraController?.dispose();

   _cameraController = CameraController(
    cameraDescription,
    ResolutionPreset.high,
    enableAudio: false,
   );

   await _cameraController!.initialize();
   await _cameraController!.startImageStream((CameraImage image) {
    _processCameraImage(image);
   });

   if (mounted) {
    setState(() {});
   }
  } catch (e) {
   if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(content: Text('Kamera başlatılamadı: $e'), backgroundColor: Colors.red),
    );
    Navigator.of(context).pop();
   }
  }
 }

 void _switchCamera() async {
  if (_availableCameras.length < 2 || _isDetecting || _isTakingPicture) return;
  await _cameraController?.stopImageStream();
  setState(() {
   _selectedLensDirection =
    _selectedLensDirection == CameraLensDirection.front
     ? CameraLensDirection.back
     : CameraLensDirection.front;
  });
  await _initializeCamera();
 }

 @override
 void dispose() {
  _pageController.dispose();
  _cameraController?.dispose();
  _selfieSegmenter.close();
  _faceDetector.close();
  _autoCaptureTimer?.cancel();
  _accelerometerSubscription?.cancel();
  _audioHelper.dispose();
  super.dispose();
 }
 

 /// YENİ: Spam korumalı, jenerik TTS uyarı tetikleyici
 void _triggerGenericWarning(VoidCallback audioFunction) {
  final now = DateTime.now();
  // YENİ: 4 saniyede bir konuşsun
  final shouldSpeak = _lastWarningTime == null ||
   now.difference(_lastWarningTime!).inSeconds >= 4; 
  
  if (shouldSpeak && _isSpeechEnabled) {
   audioFunction();
   _lastWarningTime = now;
  }
 }

 /// YENİ: Top/Back adımları için akıllı sensör mesajı döndürür
 String? _getSmartSensorWarning(String stepTag) {
  if (stepTag == 'top') {
    // Target: pitch.abs() < 25, roll.abs() < 15
    if (_devicePitch.abs() > 25) {
        return _devicePitch > 0 ? "Cihazı biraz öne eğin." : "Cihazı biraz geriye eğin.";
    } else if (_deviceRoll.abs() > 15) {
        return _deviceRoll > 0 ? "Cihazı sola yatırın." : "Cihazı sağa yatırın.";
    }
  } else if (stepTag == 'donor_area_back') {
    // Target: pitch >= -50 && pitch <= -25, roll.abs() < 15
    if (_devicePitch > -25) {
        return "Daha çok aşağı eğin.";
    } else if (_devicePitch < -50) {
        return "Çok eğdiniz, az kaldırın.";
    } else if (_deviceRoll.abs() > 15) {
        return _deviceRoll > 0 ? "Cihazı sola yatırın." : "Cihazı sağa yatırın.";
    }
  }
  return null; // Açı doğru veya ilgili adım değil
 }

 // ========================================================================
 // ==================== YENİDEN DÜZENLENMİŞ İŞLEME MANTIĞI ====================
 // ========================================================================
 Future<void> _processCameraImage(CameraImage image) async {
  if (!_areMasksLoaded || _isDetecting || _isTakingPicture) return;
  _isDetecting = true;

  try {
   final inputImage = _inputImageFromCameraImage(image);
   bool isAligned = false;
   final String currentStepTag = _steps[_currentPage]['tag']!;

   // --- 1. DOLULUK KONTROLÜ (Artık % döndürüyor) ---
   final double fillPercentage = _analyzeSegmentationMask(
    await _selfieSegmenter.processImage(inputImage), currentStepTag
   );
   const double targetFillPercentage = 0.92; // %92 hedef
   final bool isFullEnough = fillPercentage >= targetFillPercentage;

   if (!isFullEnough) {
    isAligned = false;
   } else {
    // --- 2. POZ VE SENSÖR KONTROLÜ (Akıllı uyarı eklendi) ---
    if (currentStepTag == 'top' || currentStepTag == 'donor_area_back') {
     if (!_isDeviceAngleCorrect) {
      isAligned = false;
      // YENİ: Akıllı sensör uyarısını tetikle
      String? sensorWarning = _getSmartSensorWarning(currentStepTag);
      if(sensorWarning != null) {
       _triggerGenericWarning(() => _audioHelper.speakCustom(sensorWarning));
      }
     } else {
      final faces = await _faceDetector.processImage(inputImage);
      isAligned = faces.isEmpty; // Yüz olmamalı
     }
    } else { // Ön, Sağ, Sol
     final faces = await _faceDetector.processImage(inputImage);
     if (faces.isEmpty) {
      isAligned = false;
      _triggerGenericWarning(() => _audioHelper.speakFaceNotFound());
     } else {
      final face = faces.first;
      final double? angleY = face.headEulerAngleY;
      if (angleY == null) {
       isAligned = false;
      } else {
       const double frontalTolerance = 25.0;
       const double sideAngleThreshold = 45.0;
       switch (currentStepTag) {
        case 'front': isAligned = angleY.abs() < frontalTolerance; break;
        case 'left_side': isAligned = angleY > sideAngleThreshold; break;
        case 'right_side': isAligned = angleY < -sideAngleThreshold; break;
        default: isAligned = false;
       }
      }
     }
    }
   }

   // --- 3. GEIGER BİP MANTIĞI (GÜNCELLENDİ) ---
   // DEĞİŞİKLİK: '_isSpeakingWarning' kontrolü kaldırıldı.
   // Artık hizalı değilse VE doluluk varsa HER ZAMAN çalacak.
   if (!isAligned && fillPercentage > 0.1) {
    final now = DateTime.now();
    final double progress = (fillPercentage - 0.1).clamp(0, 1) / (targetFillPercentage - 0.1);
    final int requiredDelayMs = max(150, 1000 - (850 * progress.clamp(0, 1))).toInt();

    if (_lastProgressBeepTime == null || now.difference(_lastProgressBeepTime!).inMilliseconds > requiredDelayMs) {
     _audioHelper.playTick(); // 🔊 Geiger Bip'i
     _lastProgressBeepTime = now;
    }
   } else if (isAligned) {
       _lastProgressBeepTime = null; // Hizalanınca Geiger'i sustur
   }


   // --- 4. OTOMATİK ÇEKİM MANTIĞI (TTS KALDIRILDI) ---
   if (isAligned) {
    if (!_isFaceAligned) {
     // HİZALAMA YENİ SAĞLANDI
     setState(() => _isFaceAligned = true);
     _lastProgressBeepTime = null; // Geiger'i sustur
     _audioHelper.playAlignmentSuccess(); // 🔊 Başarı Bip'i
     // KALDIRILDI: _audioHelper.speakAlignmentSuccess();

     if (_autoCaptureTimer == null && !_isTakingPicture) {
      _audioHelper.speakCountdown(); // 🗣️ SESSİZ Bip-Bip-Bip
      _autoCaptureTimer = Timer(const Duration(milliseconds: 3200), () {
       _takePicture();
       _autoCaptureTimer = null;
      });
     }
    }
   } else {
    if (_isFaceAligned) {
     // HİZALAMA YENİ KAYBOLDU
     setState(() => _isFaceAligned = false);
     _audioHelper.playAlignmentLost(); // 🔊 Uyarı Bip'i
     _audioHelper.stopAll(); // Geri sayımı kes
     _autoCaptureTimer?.cancel();
     _autoCaptureTimer = null;
    }
   }

  } catch (e) {
   print("ML Kit Hatası: $e");
  } finally {
   _isDetecting = false;
  }
 }

 // ... (analyzeSegmentationMask metodu aynı) ...
 double _analyzeSegmentationMask(SegmentationMask? mask, String currentStepTag) {
  if (mask == null) {
   return 0.0;
  }
  final List<Point<int>>? pointsToCheck = _overlaySampledPoints[currentStepTag];
  final Size? pngSize = _overlayOriginalSizes[currentStepTag];
  if (pointsToCheck == null || pngSize == null || pointsToCheck.isEmpty) {
   return 0.0;
  }
  final double scaleX = mask.width / pngSize.width;
  final double scaleY = mask.height / pngSize.height;
  int totalPointsInMask = pointsToCheck.length;
  int alignedPixelCount = 0;
  const double confidenceThreshold = 0.90;
  for (final Point<int> pngPoint in pointsToCheck) {
   final int maskX = (pngPoint.x * scaleX).floor();
   final int maskY = (pngPoint.y * scaleY).floor();
   if (maskX >= 0 && maskX < mask.width && maskY >= 0 && maskY < mask.height) {
    final int index = maskY * mask.width + maskX;
    if (index < mask.confidences.length) {
     final double confidence = mask.confidences[index];
     if (confidence > confidenceThreshold) {
      alignedPixelCount++;
     }
    }
   }
  }
  final double fillPercentage = alignedPixelCount / totalPointsInMask;
  print("ML LOG (Segmenter-$currentStepTag): Doluluk: ${(fillPercentage * 100).toStringAsFixed(1)}%");
  return fillPercentage; // Yüzdeyi döndür
 }


 /// DEĞİŞİKLİK: _takePicture (speakPhotoTaken artık sadece deklanşör çalıyor)
 Future<void> _takePicture() async {
  if (_isTakingPicture || _cameraController == null || !_cameraController!.value.isInitialized) {
   return;
  }
  try {
   setState(() => _isTakingPicture = true);

   final photo = await _cameraController!.takePicture();

   if (_currentPage < _takenPhotos.length) {
    _takenPhotos[_currentPage] = photo;
   } else {
    _takenPhotos.add(photo);
   }

   // YENİ: Bu fonksiyon artık SADECE deklanşör sesi çalıyor.
   await _audioHelper.speakPhotoTaken(); 

   if (_pageController.page! < _totalSteps - 1) {
    _hasSpokenInstructionForCurrentStep = false;
    _lastWarningTime = null;
    _lastProgressBeepTime = null; // Bip zamanlayıcısını sıfırla

    _pageController.nextPage(
     duration: const Duration(milliseconds: 300),
     curve: Curves.easeIn,
    );

    Future.delayed(const Duration(seconds: 1), () {
     if (mounted && _currentPage < _steps.length) {
      _audioHelper.speakStepInstruction(_steps[_currentPage]['tag']!);
      _hasSpokenInstructionForCurrentStep = true;
     }
    });
   }
  } catch (e) {
   if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(content: Text('Fotoğraf çekilemedi: $e'), backgroundColor: Colors.red),
    );
   }
  } finally {
   if (mounted) {
    setState(() => _isTakingPicture = false);
   }
  }
 }
 
 // ... (submitConsultation metodu aynı) ...
 void _submitConsultation() {
  if (_takenPhotos.length < _steps.length) {
   ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Lütfen tüm zorunlu 5 fotoğrafı çekin.'), backgroundColor: Colors.orange),
   );
   return;
  }
  final photosToSubmit = _takenPhotos.sublist(0, _steps.length);
  final tagsToSubmit = _steps.map((step) => step['tag']!).toList();

  context.read<ConsultationBloc>().add(
   ConsultationSubmitted(
    photos: photosToSubmit,
    angleTags: tagsToSubmit,
    medicalFormData: {"note": "Flutter (v6 - Smart Sensor TTS)"},
   ),
  );
 }

 @override
 Widget build(BuildContext context) {
  return BlocListener<ConsultationBloc, ConsultationState>(
   listener: (context, state) {
    if (state is ConsultationSuccess) {
     ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Konsültasyon Başarıyla Gönderildi!'), backgroundColor: Colors.green),
     );
     Navigator.of(context).pop();
    }
    if (state is ConsultationFailure) {
     ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Hata: ${state.error}'), backgroundColor: Colors.red),
     );
    }
   },
   child: Scaffold(
    appBar: AppBar(
     title: Text('Adım ${_currentPage + 1}/$_totalSteps'),
     leading: _currentPage == 0
      ? null
      : IconButton(
       icon: const Icon(Icons.arrow_back),
       onPressed: () {
        _audioHelper.stopAll();
        _pageController.previousPage(
         duration: const Duration(milliseconds: 300),
         curve: Curves.easeIn,
        );
       },
      ),
     actions: [
      IconButton(
       icon: Icon(_isSpeechEnabled ? Icons.volume_up : Icons.volume_off),
       tooltip: 'Sesli talimatları ${_isSpeechEnabled ? 'kapat' : 'aç'}',
       onPressed: () {
        setState(() {
         _isSpeechEnabled = !_isSpeechEnabled;
         _audioHelper.toggleSpeech(_isSpeechEnabled);
        });
       },
      ),
     ],
    ),
    body: Stack(
     children: [
      PageView.builder(
       controller: _pageController,
       physics: const NeverScrollableScrollPhysics(),
       onPageChanged: (page) {
        setState(() {
         _currentPage = page;
         _isFaceAligned = false;
         _autoCaptureTimer?.cancel();
         _autoCaptureTimer = null;
         _audioHelper.stopAll();
         // YENİ: Sayfa değişince tüm ses durumlarını sıfırla
         _lastProgressBeepTime = null;
         _lastWarningTime = null;
        });
        if (page >= _steps.length) {
         // Bu, onay ekranı demektir. Stream'i durdur.
         _cameraController?.stopImageStream();
        } else if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
         // Eğer kullanıcı onay ekranından geri dönerse stream'i yeniden başlat
         _cameraController!.startImageStream((image) {
          _processCameraImage(image);
         });
        }
       },
       itemCount: _totalSteps,
       itemBuilder: (context, index) {
        if (index < _steps.length) {
         return _buildCameraStep(index);
        } else {
         return _buildConfirmStep();
        }
       },
      ),
      // ... (Yükleniyor ekranı - BlocBuilder aynı) ...
      BlocBuilder<ConsultationBloc, ConsultationState>(
       builder: (context, state) {
        if (state is ConsultationUploadInProgress) {
         return Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
           child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
             const CircularProgressIndicator(),
             const SizedBox(height: 20),
             Text(
              state.message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
             ),
             const SizedBox(height: 10),
             Text(
              "${(state.progress * 100).toStringAsFixed(0)}%",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
             ),
            ],
           ),
          ),
         );
        }
        return const SizedBox.shrink();
       },
      ),
     ],
    ),
   ),
  );
 }
 
 // ... (buildCameraStep, buildConfirmStep, _inputImageFromCameraImage metodları aynı) ...
 Widget _buildCameraStep(int index) {
  if (_cameraController == null || !_cameraController!.value.isInitialized || !_areMasksLoaded) {
   return const Center(child: CircularProgressIndicator());
  }

  final String currentTag = _steps[index]['tag']!;
  final bool needsAngleCheck = (currentTag == 'top' || currentTag == 'donor_area_back');

  return Padding(
   padding: const EdgeInsets.all(16.0),
   child: Column(
    children: [
     Text(
      "Lütfen '${_steps[index]['label']}' bölgenizi çekin.",
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
     ),
     const SizedBox(height: 10),
     if (needsAngleCheck)
      Container(
       padding: const EdgeInsets.all(8),
       decoration: BoxDecoration(
        color: _isDeviceAngleCorrect ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
       ),
       child: Column(
        children: [
         Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
           Icon(
            _isDeviceAngleCorrect ? Icons.check_circle : Icons.warning,
            color: _isDeviceAngleCorrect ? Colors.green : Colors.orange,
           ),
           const SizedBox(width: 8),
           Text(
            _isDeviceAngleCorrect ? 'Cihaz açısı doğru!' : 'Cihaz açısını ayarlayın',
            style: TextStyle(
             color: _isDeviceAngleCorrect ? Colors.green : Colors.orange,
             fontWeight: FontWeight.bold,
            ),
           ),
          ],
         ),
         const SizedBox(height: 4),
         Text(
          'Eğim: ${_devicePitch.toStringAsFixed(1)}° | Yatay: ${_deviceRoll.toStringAsFixed(1)}°',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
         ),
        ],
       ),
      ),
     const SizedBox(height: 10),
     Expanded(
      child: AspectRatio(
       aspectRatio: 9 / 16,
       child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
         fit: StackFit.expand,
         alignment: Alignment.center,
         children: [
          CameraPreview(_cameraController!),
          Image.asset(
           'assets/overlays/${_steps[index]['tag']}.png',
           fit: BoxFit.cover,
           color: _isFaceAligned
            ? Colors.green.withOpacity(0.5)
            : Colors.white.withOpacity(0.4),
          ),
          if (_availableCameras.length > 1)
           Positioned(
            top: 8,
            right: 8,
            child: IconButton(
             style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.3),
             ),
             icon: const Icon(Icons.flip_camera_ios_outlined),
             color: Colors.white,
             iconSize: 32,
             onPressed: _switchCamera,
            ),
           ),
         ],
        ),
       ),
      ),
     ),
     const SizedBox(height: 20),
     if (_isTakingPicture)
      const CircularProgressIndicator()
     else if (_isFaceAligned)
      const Text(
       'Harika! Sabit durun, çekiliyor...', // Bu UI metni, sesli değil
       style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold),
       textAlign: TextAlign.center,
      )
     else
      Text(
       'Lütfen siluetin içini dolduracak şekilde hizalanın.',
       style: const TextStyle(fontSize: 18, color: Colors.orange, fontWeight: FontWeight.bold),
       textAlign: TextAlign.center,
      )
    ],
   ),
  );
 }

 Widget _buildConfirmStep() {
  return Padding(
   padding: const EdgeInsets.all(16.0),
   child: Column(
    children: [
     Text(
      "Çekilen Fotoğraflar (${_takenPhotos.length} adet)",
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
     ),
     const SizedBox(height: 10),
     Expanded(
      child: GridView.builder(
       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
       ),
       itemCount: _takenPhotos.length,
       itemBuilder: (context, index) {
        return ClipRRect(
         borderRadius: BorderRadius.circular(8),
         child: Image.file(
          File(_takenPhotos[index].path),
          fit: BoxFit.cover,
         ),
        );
       },
      ),
     ),
     const SizedBox(height: 10),
     ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
       backgroundColor: Colors.green,
       minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: _submitConsultation,
      icon: const Icon(Icons.upload),
      label: const Text('Tümünü Gönder ve Bitir'),
     ),
    ],
   ),
  );
 }

 InputImage _inputImageFromCameraImage(CameraImage image) {
  final camera = _cameraController!.description;
  final sensorOrientation = camera.sensorOrientation;
  final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;

  InputImageMetadata metadata;
  Uint8List bytes;

  if (Platform.isIOS) {
   final plane = image.planes.first;
   metadata = InputImageMetadata(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: rotation,
    format: InputImageFormat.bgra8888,
    bytesPerRow: plane.bytesPerRow,
   );
   bytes = plane.bytes;
  } else {
   final allBytes = WriteBuffer();
   for (final plane in image.planes) {
    allBytes.putUint8List(plane.bytes);
   }
   bytes = allBytes.done().buffer.asUint8List();

   metadata = InputImageMetadata(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: rotation,
    format: InputImageFormat.nv21,
    bytesPerRow: image.planes.first.bytesPerRow,
   );
  }

  return InputImage.fromBytes(
   bytes: bytes,
   metadata: metadata,
  );
 }
}