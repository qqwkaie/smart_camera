import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // طلب الصلاحيات
  await [
    Permission.camera,
    Permission.microphone,
    Permission.storage,
  ].request();

  try {
    _cameras = await availableCameras();
  } catch (e) {
    debugPrint('خطأ في جلب الكاميرات: $e');
  }

  runApp(const CameraApp());
}

class CameraApp extends StatelessWidget {
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const CameraHomeScreen(),
    );
  }
}

class CameraHomeScreen extends StatefulWidget {
  const CameraHomeScreen({super.key});

  @override
  State<CameraHomeScreen> createState() => _CameraHomeScreenState();
}

class _CameraHomeScreenState extends State<CameraHomeScreen> {
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    if (_cameras.isNotEmpty) {
      _initCamera(_selectedCameraIndex);
    }
  }

  Future<void> _initCamera(int cameraIndex) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    // تعيين أعلى دقة ممكنة (Ultra High / 4K)
    _controller = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.ultraHigh,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      
      // جلب حدود الزوم (0.5x حتى المدى الأقصى)
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _currentZoom = _minZoom;

      // ضبط وضع التركيز والتعريض التلقائي لتقليل الاهتزاز
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('خطأ في تهيئة الكاميرا: $e');
    }
  }

  void _switchCamera() {
    if (_cameras.length > 1) {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      _initCamera(_selectedCameraIndex);
    }
  }

  void _setZoom(double zoom) async {
    if (_controller != null && _controller!.value.isInitialized) {
      double targetZoom = zoom.clamp(_minZoom, _maxZoom);
      await _controller!.setZoomLevel(targetZoom);
      setState(() {
        _currentZoom = targetZoom;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // معاينة الكاميرا
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),

          // شريط خيارات الزوم (0.5x / 1x / 2x)
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _zoomButton(label: '0.5x', zoomValue: _minZoom),
                const SizedBox(width: 15),
                _zoomButton(label: '1x', zoomValue: 1.0),
                const SizedBox(width: 15),
                _zoomButton(label: '2x', zoomValue: 2.0.clamp(_minZoom, _maxZoom)),
              ],
            ),
          ),

          // أدوات التحكم السفلى (الالتقاط والتبديل)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // زر التبديل بين العدسات
                IconButton(
                  icon: const Icon(Icons.cameraswitch, size: 36, color: Colors.white),
                  onPressed: _switchCamera,
                ),

                // زر التصوير
                GestureDetector(
                  onTap: () async {
                    try {
                      XFile file = await _controller!.takePicture();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم التقاط الصورة بدقة 4K: ${file.name}')),
                        );
                      }
                    } catch (e) {
                      debugPrint('خطأ أثناء التقاط الصورة: $e');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: const CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),

                // مؤشر الجودة (4K)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '4K',
                    style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomButton({required String label, required double zoomValue}) {
    bool isSelected = (_currentZoom - zoomValue).abs() < 0.2;
    return GestureDetector(
      onTap: () => _setZoom(zoomValue),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellow : Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
