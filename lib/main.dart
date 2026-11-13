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
  final fps = ValueNotifier<int>(0);
  bool? camOk;
  bool portrait = true;
  int count = 0;
  DateTime lastBeep = DateTime(2000), lastLog = DateTime(2000);
  Timer? timer;
  String? yoloError; // gagal memuat model deteksi (YOLO/TFLite) saat inisialisasi

  Settings get s => widget.settings;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    player.setPlayerMode(PlayerMode.lowLatency);
    Permission.camera.request().then((st) {
      if (mounted) setState(() => camOk = st.isGranted);
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      fps.value = count;
      count = 0;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WakelockPlus.disable();
    player.dispose();
    hud.dispose();
    fps.dispose();
    super.dispose();
  }

  void testBeep() => unawaited(player.play(AssetSource('beep.wav')));

  void onResult(List<YOLOResult> results) {
    count++;
    final a = engine.evaluate(results, portrait: portrait);
    hud.value = a;
    if (a.status != 'BAHAYA') return;
    final now = DateTime.now();
    final gap = 150 + (550 * (a.dist! / s.dangerM).clamp(0.0, 1.0)).round();
    if (s.beep && now.difference(lastBeep).inMilliseconds >= gap) {
      lastBeep = now;
      testBeep();
    }
    if (now.difference(lastLog).inSeconds >= 5) {
      lastLog = now;
      History.add(a.name!, a.dist!);
    }
  }

  Color colorOf(String status) =>
      status == 'BAHAYA' ? Colors.red : (status == 'WASPADA' ? Colors.orange : Colors.green);

  String textOf(Alert a) {
    if (a.name == null) return 'AMAN • jalur depan kosong';
    final d = a.dist! > 99 ? '>99' : '${a.dist!.round()}';
    return '${a.status} • ${labelsId[a.name]} ±$d m';
  }

  Widget roundButton(IconData icon, VoidCallback onTap) => IconButton(
        icon: Icon(icon),
        iconSize: 28,
        style: IconButton.styleFrom(backgroundColor: Colors.black54),
        onPressed: onTap,
      );

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
    if (camOk == false) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Izin kamera diperlukan'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: openAppSettings, child: const Text('Buka pengaturan')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: YOLOView(
              modelPath: 'assets/models/best.tflite',
              useGpu: false, // CPU lebih stabil; menghindari crash akselerator GPU pada beberapa perangkat
              onResult: onResult,
              onModelError: (error, _modelPath, _task) {
                if (mounted) setState(() => yoloError = error.toString());
              },
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
                        valueListenable: fps,
                        builder: (_, v, _) => Text('$v deteksi/dtk',
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
                      roundButton(s.beep ? Icons.volume_up : Icons.volume_off, () {
                        s.beep = !s.beep;
                        s.save();
                      }),
                      const SizedBox(width: 16),
                      roundButton(Icons.history, () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const HistoryScreen()))),
                      const SizedBox(width: 16),
                      roundButton(Icons.settings, () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => SettingsScreen(s, testBeep)))),
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
