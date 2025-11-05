import 'dart:io';
import 'dart:async';
import 'dart:math'; // Point için eklendi
import 'dart:typed_data'; // Uint8List ve ByteData için eklendi
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 'WriteBuffer' için
import 'package:flutter/services.dart'; // rootBundle için eklendi
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img; // 'image' paketini 'img' adıyla kullan

import '/consultation/bloc/consultation_bloc.dart';
import '/consultation/bloc/consultation_event.dart';
import '/consultation/bloc/consultation_state.dart';
import '/services/api_service.dart';

// Bu ekranı HomeScreen'den veya bir "Yeni Konsültasyon Başlat" butonundan çağıracağız
class PhotoWizardScreen extends StatelessWidget {
  const PhotoWizardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ConsultationBloc(
        apiService: context.read<ApiService>(), // RepositoryProvider'dan al
      ),
      child: const _PhotoWizardView(), // Asıl işi bu widget yapacak
    );
  }
}

// Bu widget, Kamera ve Sayfa (PageView) gibi state'leri yönetir
class _PhotoWizardView extends StatefulWidget {
  const _PhotoWizardView();

  @override
  State<_PhotoWizardView> createState() => _PhotoWizardViewState();
}

class _PhotoWizardViewState extends State<_PhotoWizardView> {
  // Kontrolcüler
  late PageController _pageController;
  CameraController? _cameraController;

  // ML Kit Beyinleri
  late SelfieSegmenter _selfieSegmenter;
  late FaceDetector _faceDetector;

  bool _isDetecting = false; // "Şu an bir kareyi işliyor muyum?" (Kilit)

  // Otomatik çekim için
  Timer? _autoCaptureTimer;
  bool _isFaceAligned = false; // Silüetle hizalandı mı?

  final List<XFile> _takenPhotos = []; // Çekilen fotoğraflar

  // Adımlar
  final List<Map<String, String>> _steps = [
    {'tag': 'front', 'label': 'Ön Görünüm'},
    {'tag': 'top', 'label': 'Üst Görünüm'},
    {'tag': 'left_side', 'label': 'Sol Yan'},
    {'tag': 'right_side', 'label': 'Sağ Yan'},
    {'tag': 'donor_area_back', 'label': 'Donör Bölgesi (Arka)'},
  ];

  int get _totalSteps => _steps.length + 1; // 5 kamera + 1 onay
  int _currentPage = 0;
  bool _isTakingPicture = false;

  // --- "ZOR AMA DOĞRU" YÖNTEMİN DEĞİŞKENLERİ ---
  final Map<String, Size> _overlayOriginalSizes = {};
  final Map<String, List<Point<int>>> _overlaySampledPoints = {};
  bool _areMasksLoaded = false;
  static const int _maskSamplingRate = 20; // Her 20 pikselde 1'ini kontrol et (Hız)

  List<CameraDescription> _availableCameras = [];
  CameraLensDirection _selectedLensDirection = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // 1. BEYİN (Segmenter - Doluluk)
    _selfieSegmenter = SelfieSegmenter(
      mode: SegmenterMode.stream,
      enableRawSizeMask: true,
    );

    // 2. BEYİN (Face Detector - Hile Kontrolü)
    final faceOptions = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true, // Açılar için
      enableLandmarks: false,
      enableContours: false,
    );
    _faceDetector = FaceDetector(options: faceOptions);

    // Overlay maskelerini hafızaya al, sonra kamerayı başlat
    _loadOverlayMasksAndInitializeCamera();
  }

  /// 1. FONKSİYON: Overlay'leri yükler, sonra kamerayı başlatır
  Future<void> _loadOverlayMasksAndInitializeCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        throw Exception("Cihazda kamera bulunamadı.");
      }
      // Varsayılan 'front' kamera yoksa, bulunan ilk kamerayı seç
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

  /// 2. FONKSİYON: Tek bir overlay PNG'sini yükler ve piksellerini tarar
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
        // Alfa kanalını (şeffaflığı) doğrudan kontrol et
        if (pixel.a > 128) { // 128 = %50'den fazla opak
          sampledPoints.add(Point(x, y));
        }
      }
    }
    _overlaySampledPoints[tag] = sampledPoints;
    print("'$tag' için ${sampledPoints.length} adet kritik nokta yüklendi.");
  }

  Future<void> _initializeCamera() async {
    try {
      // --- GÜNCELLENDİ ---
      // Artık `_selectedLensDirection`'a göre kamerayı bul
      final CameraDescription cameraDescription = _availableCameras.firstWhere(
        (camera) => camera.lensDirection == _selectedLensDirection,
        // (Bu orElse'e normalde girmemesi lazım ama garanti olsun)
        orElse: () => _availableCameras.first, 
      );
      // --- GÜNCELLENDİ BİTTİ ---

      // Kamera değiştirirken, eski controller'ı at
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
        setState(() {}); // Kamera hazır
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
  
  // --- YENİ FONKSİYON: Kamera Değiştirme ---
  void _switchCamera() async {
    // Sadece 1 kamera varsa veya zaten işlem yapılıyorsa değiştirme
    if (_availableCameras.length < 2 || _isDetecting || _isTakingPicture) return;

    // Görüntü akışını durdur
    await _cameraController?.stopImageStream();
    
    // Yönü tersine çevir
    setState(() {
      _selectedLensDirection = 
        _selectedLensDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
    });
    
    // Yeni yön ile kamerayı yeniden başlat
    // (_initializeCamera zaten eski controller'ı dispose edecektir)
    await _initializeCamera();
  }
  @override
  void dispose() {
    _pageController.dispose();
    _cameraController?.dispose();
    _selfieSegmenter.close();
    _faceDetector.close();
    _autoCaptureTimer?.cancel();
    super.dispose();
  }

  // ####################################################################
  // #################### İŞTE YENİ MANTIK BURADA #######################
  // ####################################################################

  Future<void> _processCameraImage(CameraImage image) async {
  if (!_areMasksLoaded || _isDetecting || _isTakingPicture) return;
  _isDetecting = true;

  try {
    final inputImage = _inputImageFromCameraImage(image);
    bool isAligned = false;
    final String currentStepTag = _steps[_currentPage]['tag']!;

    // --- 1. ADIM: ÖNCE DOLULUK KONTROLÜ (TÜM POZLAR İÇİN) ---
    final segmentationMask = await _selfieSegmenter.processImage(inputImage);
    final bool isFullEnough = _analyzeSegmentationMask(segmentationMask, image, currentStepTag);

    if (!isFullEnough) {
      // Silüet "insan" ile dolu değilse, HİÇBİR ŞEY YAPMA.
      isAligned = false;
    } else {
      // --- 2. ADIM: DOLULUK OK. ŞİMDİ HİLE KONTROLÜ (POZA GÖRE) ---
      
      final faces = await _faceDetector.processImage(inputImage);

      // MANTIK 1: "ÜST" (top) ve "ARKA" (donor_area_back)
      // Kural: Dolu olmalı, YÜZ OLMAMALI.
      if (currentStepTag == 'top' || currentStepTag == 'donor_area_back') {
        if (faces.isNotEmpty) {
          isAligned = false; // Hata: Arkada/Üstte yüz olmamalı!
          print("ML LOG (Back/Top): Hile! Yüz algılandı.");
        } else {
          isAligned = true; // Harika: Dolu VE yüz yok.
          print("ML LOG (Back/Top): Dolu ve Yüz YOK. (OK)");
        }
      }
      // MANTIK 2: "ÖN" (front) ve "YANLAR" (left_side, right_side)
      // Kural: Dolu olmalı VE yüzün AÇISI doğru olmalı.
      else {
        if (faces.isEmpty) {
          isAligned = false; // Hata: Ön/Yan pozda bir yüz bekliyorduk ama bulamadık.
          print("ML LOG (Front/Side): Hata! Yüz bulunamadı.");
        } else {
          // Yüz bulundu. AÇISINI KONTROL ET.
          final face = faces.first;
          final double? angleY = face.headEulerAngleY; // Yaw (sağ-sol) açısı

          if (angleY == null) {
            isAligned = false;
            print("ML LOG (Front/Side): Yüz bulundu ama Açı (Y) bilgisi alınamadı.");
          } else {
            
            // "ÖN" pozu için +/- 25 derece tolerans
            const double frontalTolerance = 25.0; 
            // "YAN" pozu için 45 dereceden BÜYÜK olmalı
            const double sideAngleThreshold = 45.0; 

            if (currentStepTag == 'front') {
              // "ÖN" pozu için açının +/- 25 derece İÇİNDE olmasını istiyoruz.
              if (angleY.abs() < frontalTolerance) {
                isAligned = true; // DOĞRU POZ (Dolu VE Önden)
                print("ML LOG (Front): Dolu ve Açı Önden ($angleY). (OK)");
              } else {
                isAligned = false; // YANLIŞ POZ (Dolu ama YANDAN bakıyor)
                print("ML LOG (Front): Hile! Açı önden değil: $angleY");
              }
            } 
            // ##################################################
            // ############## İSTEDİĞİN DEĞİŞİKLİK ###############
            // ##################################################
            else if (currentStepTag == 'left_side') {
              // "SOL YAN" için, kafa SAĞA dönmeli. Açı POZİTİF olmalı.
              if (angleY > sideAngleThreshold) {
                isAligned = true; // DOĞRU POZ (Dolu VE Sol Yan)
                print("ML LOG (Left-Side): Dolu ve Açı Sol Yandan ($angleY). (OK)");
              } else {
                isAligned = false; // YANLIŞ POZ (Yanlış yön veya yeterince dönülmedi)
                print("ML LOG (Left-Side): Yanlış yön veya yeterince dönülmedi: $angleY");
              }
            }
            else { // 'right_side'
              // "SAĞ YAN" için, kafa SOLA dönmeli. Açı NEGATİF olmalı.
              if (angleY < -sideAngleThreshold) {
                isAligned = true; // DOĞRU POZ (Dolu VE Sağ Yan)
                print("ML LOG (Right-Side): Dolu ve Açı Sağ Yandan ($angleY). (OK)");
              } else {
                isAligned = false; // YANLIŞ POZ (Yanlış yön veya yeterince dönülmedi)
                print("ML LOG (Right-Side): Yanlış yön veya yeterince dönülmedi: $angleY");
              }
            }
            // ##################################################
            // ############ DEĞİŞİKLİK BİTİŞİ ###################
            // ##################################################
          }
        }
      }
    }

    // --- OTOMATİK ÇEKİM MANTIĞI (Bu kısım aynı) ---
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
    // --- Otomatik Çekim Sonu ---

  } catch (e) {
    print("ML Kit Hatası: $e");
  } finally {
    _isDetecting = false;
  }
}


  /// GÜNCELLENMİŞ FONKSİYON: "GERÇEK" maske ile doluluk analizi (TÜM POZLAR İÇİN)
  bool _analyzeSegmentationMask(SegmentationMask? mask, CameraImage image, String currentStepTag) {
    if (mask == null) {
      print("ML LOG (Segmenter): Maske bulunamadı (Ekranda insan yok).");
      return false;
    }

    // Hafızadan o adımın (top.png, left.png) "gerçek" noktalarını al
    final List<Point<int>>? pointsToCheck = _overlaySampledPoints[currentStepTag];
    final Size? pngSize = _overlayOriginalSizes[currentStepTag];

    if (pointsToCheck == null || pngSize == null || pointsToCheck.isEmpty) {
      print("Hata: '$currentStepTag' için overlay noktaları bulunamadı.");
      return false;
    }

    // Koordinat sistemlerini eşitlemek için ölçekleme faktörleri
    // (PNG'nin koordinatlarını -> ML Kit Mask'in koordinatlarına çevir)
    // Bu, PNG'nin ve Kameranın (ve ML maskesinin) 9:16 olduğunu varsayar
    final double scaleX = mask.width / pngSize.width;
    final double scaleY = mask.height / pngSize.height;

    int totalPointsInMask = pointsToCheck.length;
    int alignedPixelCount = 0;
    
    // Güven eşiği (%90'dan fazla 'insan' olmalı)
    const double confidenceThreshold = 0.90; 

    // O adıma ait silüetin (örn: top.png) içindeki her bir 'gerçek' noktanın
    // ML Kit'in 'insan' haritasında "insan" olarak işaretlenip işaretlenmediğini kontrol et
    for (final Point<int> pngPoint in pointsToCheck) {
      // PNG noktasını, ML Kit Mask koordinatına ölçekle
      final int maskX = (pngPoint.x * scaleX).floor();
      final int maskY = (pngPoint.y * scaleY).floor();

      // Bu noktanın maske sınırları içinde olduğundan emin ol
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

    
    const double targetFillPercentage = 0.95; 
    
    final bool isAligned = fillPercentage >= targetFillPercentage;
    
   
    print("ML LOG (Segmenter-$currentStepTag): Overlay Doldurma (insan ile): ${(fillPercentage * 100).toStringAsFixed(1)}% - Hizalı mı?: $isAligned");

    return isAligned;
  }



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

      if (_pageController.page! < _totalSteps - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
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
        medicalFormData: {"note": "Flutter'dan yüklendi (Pixel Perfect v2)"},
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
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                ),
              ),
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
            const Text(
              'Lütfen kafanızı silüetin içini dolduracak şekilde hizalayın.',
              style: TextStyle(fontSize: 18, color: Colors.orange, fontWeight: FontWeight.bold),
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
        format: InputImageFormat.bgra8888, // iOS
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
        format: InputImageFormat.nv21, // Android
        bytesPerRow: image.planes.first.bytesPerRow,
      );
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: metadata,
    );
  }
}