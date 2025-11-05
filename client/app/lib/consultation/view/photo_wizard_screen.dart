import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/consultation/bloc/consultation_bloc.dart';
import '/consultation/bloc/consultation_event.dart';
import '/consultation/bloc/consultation_state.dart';
import '/services/api_service.dart'; // ApiService'i BLoC'a vermek için

// Bu ekranı HomeScreen'den veya bir "Yeni Konsültasyon Başlat" butonundan çağıracağız
class PhotoWizardScreen extends StatelessWidget {
  const PhotoWizardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Bu ekran, kendi BLoC'unu oluşturur ve yönetir.
    // Ekran kapandığında BLoC da otomatik olarak ölür (dispose).
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
  CameraController? _cameraController; // Kamera, 'null' olabilir
  
  final List<XFile> _takenPhotos = []; // Çekilen fotoğrafları tutan liste
  
  // Backend'deki enum ile eşleşen etiketler
  final List<Map<String, String>> _steps = [
    {'tag': 'front', 'label': 'Ön Görünüm'},
    {'tag': 'top', 'label': 'Üst Görünüm'},
    {'tag': 'left_side', 'label': 'Sol Yan'},
    {'tag': 'right_side', 'label': 'Sağ Yan'},
    {'tag': 'donor_area_back', 'label': 'Donör Bölgesi (Arka)'},
    {'tag': 'other', 'label': 'Ek Görünüm (Opsiyonel)'},
  ];
  
  // Toplam adım sayısı: 6 kamera + 1 onay ekranı
  int get _totalSteps => _steps.length + 1;
  int _currentPage = 0;
  bool _isTakingPicture = false; // <-- YENİ SATIR (Butonu kilitlemek için)
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeCamera(); // Kamerayı başlatan fonksiyon
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.first; // Genellikle arka kamera

      _cameraController = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false, // Ses kaydına ihtiyacımız yok
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {}); // Kamera hazır, ekranı güncelle
      }
    } catch (e) {
      // Kameraya erişim izni reddedilirse veya başka bir hata olursa
      if (mounted) {
        // Hata durumunu BLoC'a bildir (veya SnackBar göster)
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Kamera başlatılamadı: $e'), backgroundColor: Colors.red),
        );
        Navigator.of(context).pop(); // Bu ekranı kapat
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cameraController?.dispose(); // Kamera 'null' değilse kapat
    super.dispose();
  }

  Future<void> _takePicture() async {
  // EĞER ZATEN BİR FOTOĞRAF ÇEKİLİYORSA, BU FONKSİYONU TEKRAR ÇALIŞTIRMA
  if (_isTakingPicture || _cameraController == null || !_cameraController!.value.isInitialized) {
    return; // Kamera hazır değil VEYA zaten meşgul
  }

  try {
    // 1. Kilidi tak
    setState(() => _isTakingPicture = true);

    // 2. Fotoğrafı çek
    final photo = await _cameraController!.takePicture();

    // 3. Fotoğrafı listeye ekle (setState içinde değil)
    if (_currentPage < _takenPhotos.length) {
      _takenPhotos[_currentPage] = photo;
    } else {
      _takenPhotos.add(photo);
    }

    // 4. Bir sonraki adıma geç
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
    // 5. Hata olsa da olmasa da, kilidi geri aç
    if (mounted) {
      setState(() => _isTakingPicture = false);
    }
  }
}

  // Gönderme (Submit) fonksiyonu
  void _submitConsultation() {
    // Çekilen fotoğraf sayısı ile etiket sayısının uyuştuğunu kontrol et
    // (Opsiyonel olan 'other' hariç)
    if(_takenPhotos.length < _steps.length - 1) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Lütfen tüm zorunlu fotoğrafları çekin.'), backgroundColor: Colors.orange),
      );
      return;
    }

    // BLoC'a event'i yolla
    context.read<ConsultationBloc>().add(
      ConsultationSubmitted(
        photos: _takenPhotos,
        angleTags: _steps.map((step) => step['tag']!).toList().sublist(0, _takenPhotos.length),
        medicalFormData: {"note": "Flutter'dan yüklendi"}, // TODO: Formdan al
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // BlocListener ve BlocBuilder ile UI'ı yönet
    return BlocListener<ConsultationBloc, ConsultationState>(
      listener: (context, state) {
        if (state is ConsultationSuccess) {
          // Yükleme başarılıysa, Ana Sayfaya yönlendir ve 'Başarılı' de
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konsültasyon Başarıyla Gönderildi!'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(); // Sihirbaz ekranını kapat
        }
        if (state is ConsultationFailure) {
          // Hata SnackBar'ı göster
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: ${state.error}'), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Adım ${_currentPage + 1}/$_totalSteps'),
          // Geri butonu
          leading: _currentPage == 0 
            ? null // İlk adımda geri butonu gösterme
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
            // Arkaplan: PageView (Adım Adım Sihirbaz)
            PageView.builder(
              controller: _pageController,
              // Kaydırmayı engelle, sadece butonlarla geçilsin
              physics: const NeverScrollableScrollPhysics(), 
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: _totalSteps,
              itemBuilder: (context, index) {
                if (index < _steps.length) {
                  // ADIM 1-6: Kamera Ekranı
                  return _buildCameraStep(index);
                } else {
                  // SON ADIM: Onay Ekranı
                  return _buildConfirmStep();
                }
              },
            ),
            
            // Önplan: Yükleniyor Overlay'i
            BlocBuilder<ConsultationBloc, ConsultationState>(
              builder: (context, state) {
                if (state is ConsultationUploadInProgress) {
                  // Yükleniyorsa, ekranı karart ve ilerlemeyi göster
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
                // Yüklenmiyorsa, hiçbir şey gösterme
                return const SizedBox.shrink(); 
              },
            ),
          ],
        ),
      ),
    );
  }

  // Kamera Adımını çizen Widget
  Widget _buildCameraStep(int index) {
    // Kamera hala yükleniyorsa
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white)); 
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            "Lütfen '${_steps[index]['label']}' bölgenizin fotoğrafını çekin.", 
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AspectRatio(
              aspectRatio: 9 / 16, // Telefon kamerası oranı
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    // Kamera önizlemesi
                    CameraPreview(_cameraController!),
                    
                    // TODO: Buraya 'assets' klasöründen silüet/overlay PNG'si ekle
                    // Örn: Yüz silüeti
                    // Image.asset(
                    //   'assets/overlays/${_steps[index]['tag']}.png',
                    //   fit: BoxFit.cover,
                    //   color: Colors.white.withOpacity(0.3),
                    // ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50), // Geniş buton
            ),
           onPressed: _isTakingPicture ? null : _takePicture,
          icon: _isTakingPicture 
              ? const SizedBox.shrink() // Yüklenirken ikon gösterme
              : const Icon(Icons.camera_alt),
          label: _isTakingPicture
              ? const CircularProgressIndicator(color: Colors.white) // Yükleniyorsa dönen çark
              : const Text('Fotoğraf Çek'), // Normalde yazı
        ),
      ],
    ),
  );
}
  
  // Onay Adımını çizen Widget
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
            // Çekilen fotoğrafları grid'de göster
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
          // TODO: Buraya 'medicalFormData' için ek TextField'lar eklenebilir
          
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: _submitConsultation, // BLoC event'ini tetikle
            icon: const Icon(Icons.upload),
            label: const Text('Tümünü Gönder ve Bitir'),
          ),
        ],
      ),
    );
  }
}