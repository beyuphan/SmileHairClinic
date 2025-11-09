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
// import 'package:audioplayers/audioplayers.dart'; // <-- KALDIRILDI
// import 'package:flutter_tts/flutter_tts.dart'; // <-- KALDIRILDI

import '/consultation/bloc/consultation_bloc.dart';
import '/consultation/bloc/consultation_event.dart';
import '/consultation/bloc/consultation_state.dart';
import '/services/api_service.dart';
import '/helper/audio_helper.dart'; // <-- YENİ IMPORT

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

 // ========== YENİ: SENSÖR DEĞİŞKENLERİ ==========
 StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
 double _devicePitch = 0.0; // Cihazın öne/arkaya eğimi (derece)
 double _deviceRoll = 0.0; // Cihazın sağa/sola eğimi (derece)
 bool _isDeviceAngleCorrect = false; // Sensör açısı doğru mu?

 // ========== YENİ: SES YÖNETİCİSİ ==========
 late AudioFeedbackHelper _audioHelper;
 bool _hasSpokenInstructionForCurrentStep = false;
 bool _hasPlayedAlignmentSound = false;
 bool _isSpeechEnabled = true; // UI için ayrı flag
 DateTime? _lastWarningTime;


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
   enableLandmarks: false,
   enableContours: false,
  );
  _faceDetector = FaceDetector(options: faceOptions);

  _audioHelper = AudioFeedbackHelper(); // YENİ: Ses yöneticisini başlat

  _loadOverlayMasksAndInitializeCamera();
  _startAccelerometerListener();
 }

 // ========== YENİ: ACCELEROMETER DİNLEYİCİSİ ==========
 void _startAccelerometerListener() {
  _accelerometerSubscription = accelerometerEventStream(
   samplingPeriod: const Duration(milliseconds: 200), // 5 Hz
  ).listen((AccelerometerEvent event) {
   if (!mounted) return;

   // Accelerometer değerlerinden pitch ve roll hesapla
   // x: Sağa/sola eğim, y: İleri/geri eğim, z: Yukarı/aşağı (yerçekimi)
   final double x = event.x;
   final double y = event.y;
   final double z = event.z;

   // Pitch: Cihazın öne/arkaya eğimi (0° = düz, +90° = yukarı bakan, -90° = aşağı bakan)
   final double pitch = atan2(y, sqrt(x * x + z * z)) * (180 / pi);
   
   // Roll: Cihazın sağa/sola eğimi (0° = düz, +90° = sağa yatık, -90° = sola yatık)
   final double roll = atan2(x, sqrt(y * y + z * z)) * (180 / pi);

   setState(() {
    _devicePitch = pitch;
    _deviceRoll = roll;
    _checkDeviceAngle(); // Açı kontrolünü yap
   });
  });
 }

 // ========== YENİ: CİHAZ AÇISI KONTROLÜ ==========
 void _checkDeviceAngle() {
  final String currentStepTag = _steps[_currentPage]['tag']!;
  bool angleOk = false;

  if (currentStepTag == 'top') {
   // TEPE (TOP): Cihaz neredeyse düz (yere paralel) tutulmalı
   // Pitch: -20° ile +20° arası (hafif tolerans)
   // Roll: -15° ile +15° arası
   angleOk = _devicePitch.abs() < 25 && _deviceRoll.abs() < 15;
   
  } else if (currentStepTag == 'donor_area_back') {
   // ARKA (DONOR_AREA_BACK): Cihaz hafif aşağı eğik (başın arkasını görmek için)
   // Pitch: -60° ile -30° arası (aşağıya doğru eğik)
   // Roll: -15° ile +15° arası
   angleOk = (_devicePitch >= -50 && _devicePitch <= -25) && _deviceRoll.abs() < 15;
   
  } else {
   // ÖN, SAĞ, SOL: Cihaz normal dik pozisyonda (sensör kontrolü gerekmez)
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
    print("Tüm overlay maskeleri başarıyla yüklendi ve örneklendi.");
    _initializeCamera();
    
    // İLK ADIM İÇİN TALİMAT VER (2 saniye sonra) 🔊
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
  print("'$tag' için ${sampledPoints.length} adet kritik nokta yüklendi.");
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
  _audioHelper.dispose(); // YENİ: Ses kaynaklarını temizle
  super.dispose();
 }

 // ========== GÜNCELLENMİŞ: SENSÖR + YÜZ + DOLULUK KONTROLÜ ==========
 Future<void> _processCameraImage(CameraImage image) async {
  if (!_areMasksLoaded || _isDetecting || _isTakingPicture) return;
  _isDetecting = true;

  try {
   final inputImage = _inputImageFromCameraImage(image);
   bool isAligned = false;
   final String currentStepTag = _steps[_currentPage]['tag']!;

   // --- 1. ADIM: DOLULUK KONTROLÜ (TÜM POZLAR İÇİN) ---
   final segmentationMask = await _selfieSegmenter.processImage(inputImage);
   final bool isFullEnough = _analyzeSegmentationMask(segmentationMask, image, currentStepTag);

   if (!isFullEnough) {
    isAligned = false;
   } else {
    // --- 2. ADIM: DOLULUK OK. ŞİMDİ POZ + SENSÖR KONTROLÜ ---
    
    // **YENİ MANTIK: TEPE ve ARKA için SENSÖR kontrolü ekle**
    if (currentStepTag == 'top' || currentStepTag == 'donor_area_back') {
     // Önce sensör açısını kontrol et
     if (!_isDeviceAngleCorrect) {
      isAligned = false;
      print("ML LOG ($currentStepTag): Cihaz açısı yanlış! Pitch: ${_devicePitch.toStringAsFixed(1)}°, Roll: ${_deviceRoll.toStringAsFixed(1)}°");
     } else {
      // Sensör OK, şimdi yüz kontrolü (olmamalı)
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
       isAligned = false;
       print("ML LOG ($currentStepTag): Hile! Yüz algılandı.");
      } else {
       isAligned = true;
       print("ML LOG ($currentStepTag): Dolu, Sensör OK, Yüz YOK. ✓");
      }
     }
    } 
    // ÖN, SAĞ, SOL: Mevcut mantık (sadece yüz açısı kontrolü)
    else {
     final faces = await _faceDetector.processImage(inputImage);
     if (faces.isEmpty) {
      isAligned = false;
      print("ML LOG ($currentStepTag): Hata! Yüz bulunamadı.");
     } else {
      final face = faces.first;
      final double? angleY = face.headEulerAngleY;

      if (angleY == null) {
       isAligned = false;
       print("ML LOG ($currentStepTag): Yüz bulundu ama Açı (Y) bilgisi alınamadı.");
      } else {
       const double frontalTolerance = 25.0; 
       const double sideAngleThreshold = 45.0; 

       if (currentStepTag == 'front') {
        if (angleY.abs() < frontalTolerance) {
         isAligned = true;
         print("ML LOG (Front): Dolu ve Açı Önden ($angleY). ✓");
        } else {
         isAligned = false;
         print("ML LOG (Front): Hile! Açı önden değil: $angleY");
        }
       } 
       else if (currentStepTag == 'left_side') {
        if (angleY > sideAngleThreshold) {
         isAligned = true;
         print("ML LOG (Left-Side): Dolu ve Açı Sol Yandan ($angleY). ✓");
        } else {
         isAligned = false;
         print("ML LOG (Left-Side): Yanlış yön veya yeterince dönülmedi: $angleY");
        }
       }
       else { // 'right_side'
        if (angleY < -sideAngleThreshold) {
         isAligned = true;
         print("ML LOG (Right-Side): Dolu ve Açı Sağ Yandan ($angleY). ✓");
        } else {
         isAligned = false;
         print("ML LOG (Right-Side): Yanlış yön veya yeterince dönülmedi: $angleY");
        }
       }
      }
     }
    }
   }

   // --- OTOMATİK ÇEKİM MANTIĞı ---
   if (isAligned) {
    if (!_isFaceAligned) {
     if (mounted) setState(() => _isFaceAligned = true);
    }
    if (_autoCaptureTimer == null && !_isTakingPicture) {
     _autoCaptureTimer = Timer(const Duration(seconds: 3), () {
      _takePicture();
      _autoCaptureTimer = null;
     });
    }
   } else {
    if (_isFaceAligned) {
     if (mounted) setState(() => _isFaceAligned = false);
    }
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
   }

  } catch (e) {
   print("ML Kit Hatası: $e");
  } finally {
   _isDetecting = false;
  }
 }

 bool _analyzeSegmentationMask(SegmentationMask? mask, CameraImage image, String currentStepTag) {
  if (mask == null) {
   print("ML LOG (Segmenter): Maske bulunamadı (Ekranda insan yok).");
   return false;
  }

  final List<Point<int>>? pointsToCheck = _overlaySampledPoints[currentStepTag];
  final Size? pngSize = _overlayOriginalSizes[currentStepTag];

  if (pointsToCheck == null || pngSize == null || pointsToCheck.isEmpty) {
   print("Hata: '$currentStepTag' için overlay noktaları bulunamadı.");
   return false;
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
  
  // ========== YENİ: MANTIKLI EŞİKLER VE SES TETİKLEYİCİLERİ ==========
  const double targetFillPercentage = 0.92; // %95 çok katı, %92 yeterli
  const double warningThreshold = 0.85;   // %85'in altında uyarı ver
  const double tooFarThreshold = 0.50;   // %50'nin altında "çok uzak" uyarısı
  
  final bool isAligned = fillPercentage >= targetFillPercentage;
  
  // Ses Tetikleyicileri (Her 3 saniyede bir konuşsun, spam olmasın)
  final now = DateTime.now();
  final shouldSpeak = _lastWarningTime == null || 
            now.difference(_lastWarningTime!).inSeconds >= 3;
  
  if (shouldSpeak) {
   if (fillPercentage < tooFarThreshold) {
    // ÇOK UZAK (<%50): "Daha yakın durun"
    _audioHelper.speakCustom("Lütfen kameraya daha yakın durun");
    _lastWarningTime = now;
   } else if (fillPercentage >= tooFarThreshold && fillPercentage < warningThreshold) {
    // ORTA MESAFE (%50-%85): "Biraz daha yaklaşın"
    _audioHelper.speakCustom("Biraz daha yaklaşın ve siluetin içini doldurun");
    _lastWarningTime = now;
   } else if (fillPercentage >= warningThreshold && fillPercentage < targetFillPercentage) {
    // NEREDEYSE TAMAM (%85-%92): "Çok yakın, biraz daha"
    _audioHelper.speakCustom("Çok yaklaştınız, biraz daha");
    _lastWarningTime = now;
   }
  }
  
  print("ML LOG (Segmenter-$currentStepTag): Overlay Doldurma (insan ile): ${(fillPercentage * 100).toStringAsFixed(1)}% - Hizalı mı?: $isAligned");

  return isAligned;
 }

 Future<void> _takePicture() async {
  if (_isTakingPicture || _cameraController == null || !_cameraController!.value.isInitialized) {
   return;
  }

  try {
   setState(() => _isTakingPicture = true);
   
   // 1. FOTOĞRAF ÇEKİM SESİ ÇAL 📸
   // _audioHelper.playShutterSound(); // speakPhotoTaken içinde zaten var
   
   final photo = await _cameraController!.takePicture();

   if (_currentPage < _takenPhotos.length) {
    _takenPhotos[_currentPage] = photo;
   } else {
    _takenPhotos.add(photo);
   }

   // 2. "ÇEKİM TAMAMLANDI" SESLİ GERİ BİLDİRİM 🔊
   _audioHelper.speakPhotoTaken();

   if (_pageController.page! < _totalSteps - 1) {
    // Sayfa değişirken ses flaglerini sıfırla
    _hasSpokenInstructionForCurrentStep = false;
    _hasPlayedAlignmentSound = false;
    
    _pageController.nextPage(
     duration: const Duration(milliseconds: 300),
     curve: Curves.easeIn,
    );
    
    // 3. YENİ ADIM İÇİN TALİMAT VER (1 saniye sonra) 🔊
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

 void _submitConsultation() {
  if(_takenPhotos.length < _steps.length) { 
   ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Lütfen tüm zorunlu 5 fotoğrafı çekin.'), backgroundColor: Colors.orange),
   );
   return;
  }

  context.read<ConsultationBloc>().add(
   ConsultationSubmitted(
    photos: _takenPhotos,
    angleTags: _steps.map((step) => step['tag']!).toList().sublist(0, _takenPhotos.length),
    medicalFormData: {"note": "Flutter'dan yüklendi (Sensör + ML Kit v3)"},
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
         _audioHelper.stopAll(); // Sesleri durdur
         _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
         );
        },
       ),
     actions: [
      // YENİ: Ses kontrol butonu
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
       onPageChanged: (page) => setState(() => _currentPage = page),
       itemCount: _totalSteps,
       itemBuilder: (context, index) {
        if (index < _steps.length) {
         return _buildCameraStep(index);
        } else {
         return _buildConfirmStep();
        }
       },
      ),
      
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

 Widget _buildCameraStep(int index) {
  if (_cameraController == null || !_cameraController!.value.isInitialized || !_areMasksLoaded) {
   return Center(
    child: Column(
     mainAxisAlignment: MainAxisAlignment.center,
     children: [
      const CircularProgressIndicator(color: Colors.white),
      const SizedBox(height: 20),
      Text(
       _areMasksLoaded ? "Kamera başlatılıyor..." : "Maskeler yükleniyor...",
       style: const TextStyle(color: Colors.white),
      ),
     ],
    ),
   );
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
     
     // YENİ: Sensör açı göstergesi (sadece TEPE ve ARKA için)
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
          'Pitch: ${_devicePitch.toStringAsFixed(1)}° | Roll: ${_deviceRoll.toStringAsFixed(1)}°',
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
       'Harika! Sabit durun, çekiliyor...',
       style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold),
       textAlign: TextAlign.center,
      )
     else
      Text(
       needsAngleCheck 
        ? 'Lütfen cihazı doğru açıda tutup kafanızı silueti doldurun.'
        : 'Lütfen kafanızı siluetin içini dolduracak şekilde hizalayın.',
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

// ========================================================================
// ==================== SES GERİ BİLDİRİMİ YARDIMCISI ====================
// ========================================================================
// 
// (BU KISIM ARTIK YENİ DOSYAYA TAŞINACAK)
//
// class AudioFeedbackHelper {
//  ...
// }