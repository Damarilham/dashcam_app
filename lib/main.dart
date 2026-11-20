import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = Settings();
  try {
    await settings.load();
  } catch (_) {
    // Gagal membaca preferensi; gunakan nilai default agar aplikasi tetap dapat dibuka.
  }
  runApp(MaterialApp(
    title: 'Dashcam Detect',
    theme: ThemeData.dark(useMaterial3: true),
    home: HomePage(settings),
  ));
}

class HomePage extends StatefulWidget {
  const HomePage(this.settings, {super.key});
  final Settings settings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final engine = Engine(widget.settings);
  final player = AudioPlayer();
  final hud = ValueNotifier<Alert>(const Alert('AMAN'));
  final camFps = ValueNotifier<int>(0);
  final detFps = ValueNotifier<int>(0);
  bool? camOk;
  bool portrait = true;
  int camFrameCount = 0;
  int detFrameCount = 0;
  int _frameSkipCounter = 0;
  int _detectionIntervalFrames = 3;
  DateTime _lastBeep = DateTime(2000);
  DateTime _lastLog = DateTime(2000);
  Timer? timer;
  String? yoloError;
  bool _detectionPaused = false;
  bool _isCameraActive = false; // kamera belum aktif; tampilkan dashboard

  Settings get s => widget.settings;

  @override
  void initState() {
    super.initState();
    if (s.wakelock) WakelockPlus.enable();
    s.addListener(() {
      if (s.wakelock) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
      setState(() => _detectionIntervalFrames = s.detectionIntervalFrames);
    });
    _detectionIntervalFrames = s.detectionIntervalFrames;
    player.setPlayerMode(PlayerMode.lowLatency);
    Permission.camera.request().then((st) {
      if (mounted) setState(() => camOk = st.isGranted);
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        camFps.value = camFrameCount;
        detFps.value = detFrameCount;
        camFrameCount = 0;
        detFrameCount = 0;
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WakelockPlus.disable();
    player.dispose();
    hud.dispose();
    camFps.dispose();
    detFps.dispose();
    super.dispose();
  }

  void _startCamera() {
    if (!mounted) return;
    if (camOk == false) {
      openAppSettings();
      return;
    }
    setState(() => _isCameraActive = true);
    _detectionPaused = false;
  }

  void _stopCamera() {
    if (!mounted) return;
    setState(() {
      _isCameraActive = false;
      _detectionPaused = true;
    });
    hud.value = const Alert('AMAN');
  }

  void testBeep() => unawaited(player.play(AssetSource('beep.wav')));

  void _maybeBeep(Alert a) {
    if (!s.beep) return;
    final now = DateTime.now();
    int minInterval;
    if (a.status == 'BAHAYA') {
      minInterval = 600; // beep cepat saat bahaya
    } else if (a.status == 'WASPADA') {
      minInterval = 1500; // beep lebih lambat saat waspada
    } else {
      return;
    }
    if (now.difference(_lastBeep).inMilliseconds >= minInterval) {
      _lastBeep = now;
      testBeep();
    }
  }

  void onResult(List<YOLOResult> results) {
    if (!mounted || _detectionPaused || !_isCameraActive) return;

    camFrameCount++;
    _frameSkipCounter++;
    if (_frameSkipCounter < _detectionIntervalFrames) return;
    _frameSkipCounter = 0;

    try {
      detFrameCount++;
      final now = DateTime.now();
      final a = engine.evaluate(results, portrait: portrait);
      if (!mounted) return;
      hud.value = a;

      // Adaptive skip
      if (a.status != 'BAHAYA') {
        _detectionIntervalFrames = 5;
      } else {
        _detectionIntervalFrames = 3;
      }

      _maybeBeep(a);

      if (now.difference(_lastLog).inSeconds >= 30 &&
          (a.status == 'BAHAYA' || a.status == 'WASPADA') &&
          a.name != null) {
        _lastLog = now;
        History.add(a.name!, a.dist!);
      }
    } catch (e) {
      if (mounted) setState(() => yoloError = e.toString());
    }
  }

  Color colorOf(String status) =>
      status == 'BAHAYA' ? Colors.red : (status == 'WASPADA' ? Colors.orange : Colors.green);

  String textOf(Alert a) {
    if (a.name == null) return 'AMAN • jalur depan kosong';
    final d = a.dist! > 99 ? '>99' : '${a.dist!.round()}';
    return '${a.status} • ${labelsId[a.name]} ±$d m';
  }

  Widget roundButton(IconData icon, VoidCallback onTap, {String? label}) => IconButton(
        icon: Icon(icon),
        iconSize: 28,
        style: IconButton.styleFrom(backgroundColor: Colors.black54),
        onPressed: onTap,
        tooltip: label,
      );

  Widget _buildDashboard() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_car, color: Colors.white70, size: 80),
              const SizedBox(height: 24),
              const Text(
                'Dashcam Detect',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Deteksi bahaya depan kendaraan\nPeringatan suara dan visual',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 260,
                child: ElevatedButton.icon(
                  onPressed: camOk == false ? null : _startCamera,
                  icon: const Icon(Icons.videocam),
                  label: const Text(
                    'Mulai Deteksi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SettingsScreen(s, testBeep)),
                      ),
                      icon: const Icon(Icons.settings, size: 20),
                      label: const Text('Pengaturan', style: TextStyle(fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistoryScreen()),
                      ),
                      icon: const Icon(Icons.history, size: 20),
                      label: const Text('Riwayat', style: TextStyle(fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              if (camOk == false) ...[
                const SizedBox(height: 24),
                const Text(
                  'Izin kamera belum diberikan',
                  style: TextStyle(color: Colors.orange, fontSize: 14),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 260,
                  child: ElevatedButton.icon(
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.open_in_new, size: 20),
                    label: const Text('Buka Pengaturan Aplikasi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Tempatkan ponsel di depan kaca depan kendaraan\ndengan pemandangan jalan yang jelas.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isCameraActive)
            Positioned.fill(
              child: YOLOView(
                modelPath: 'assets/models/best.tflite',
                useGpu: false,
                onResult: onResult,
                onModelError: (error, _, __) {
                  if (mounted) setState(() => yoloError = error.toString());
                },
              ),
            )
          else
            const Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off, color: Colors.white54, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Kamera dihentikan',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tekan Mulai untuk memulai deteksi',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: s,
                builder: (_, _) => CustomPaint(painter: LanePainter(s.laneHalf)),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ValueListenableBuilder<Alert>(
                valueListenable: hud,
                builder: (_, a, _) => Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorOf(a.status).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        textOf(a),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: camFps,
                        builder: (_, v, _) => Text('$v fps kamera',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<int>(
                        valueListenable: detFps,
                        builder: (_, v, _) => Text('$v detik/dtk',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ListenableBuilder(
                  listenable: s,
                  builder: (_, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      roundButton(
                        _detectionPaused ? Icons.play_arrow : Icons.pause,
                        () => setState(() => _detectionPaused = !_detectionPaused),
                        label: _detectionPaused ? 'Resume' : 'Pause',
                      ),
                      const SizedBox(width: 12),
                      roundButton(
                        Icons.stop,
                        _stopCamera,
                        label: 'Stop Kamera',
                      ),
                      const SizedBox(width: 12),
                      roundButton(Icons.history, () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistoryScreen()),
                      )),
                      const SizedBox(width: 12),
                      roundButton(Icons.settings, () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SettingsScreen(s, testBeep)),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    portrait = MediaQuery.of(context).orientation == Orientation.portrait;

    if (yoloError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                'Model deteksi gagal dimuat',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  yoloError!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() => yoloError = null),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (camOk == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (camOk == false && !_isCameraActive) {
      return _buildDashboard();
    }

    if (!_isCameraActive) {
      return _buildDashboard();
    }

    return _buildCameraView();
  }
}

class LanePainter extends CustomPainter {
  LanePainter(this.half);
  final double half;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.5;
    for (final x in [0.5 - half, 0.5 + half]) {
      canvas.drawLine(Offset(x * size.width, 0), Offset(x * size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(LanePainter old) => old.half != half;
}

