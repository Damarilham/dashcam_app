import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

const sizes = <String, List<double>>{
  'pedestrian': [0.5, 1.7],
  'rider': [0.7, 1.6],
  'bicycle': [0.6, 1.1],
  'motorcycle': [0.8, 1.5],
  'car': [1.8, 1.5],
  'truck': [2.5, 3.2],
  'bus': [2.5, 3.2],
};
const vehicles = {'car', 'truck', 'bus', 'motorcycle'};
const people = {'pedestrian', 'rider', 'bicycle'};
const labelsId = {
  'car': 'Mobil',
  'truck': 'Truk',
  'bus': 'Bus',
  'motorcycle': 'Motor',
  'pedestrian': 'Pejalan kaki',
  'rider': 'Pengendara',
  'bicycle': 'Sepeda',
};
const frameAspect = 16 / 9;
const alertFrames = 3;

class Settings extends ChangeNotifier {
  double dangerM = 10, warnM = 25, hfov = 70, laneHalf = 0.2, minConf = 0.4, minConfMotorcycle = 0.3;
  bool beep = true, includePeople = false, wakelock = false;
  int detectionIntervalFrames = 3; // deteksi setiap N frame (semakin besar semakin ringan)

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    dangerM = p.getDouble('dangerM') ?? dangerM;
    warnM = p.getDouble('warnM') ?? warnM;
    hfov = p.getDouble('hfov') ?? hfov;
    laneHalf = p.getDouble('laneHalf') ?? laneHalf;
    minConf = p.getDouble('minConf') ?? minConf;
    minConfMotorcycle = p.getDouble('minConfMotorcycle') ?? minConfMotorcycle;
    beep = p.getBool('beep') ?? beep;
    includePeople = p.getBool('includePeople') ?? includePeople;
    wakelock = p.getBool('wakelock') ?? wakelock;
    detectionIntervalFrames = p.getInt('detectionIntervalFrames') ?? detectionIntervalFrames;
  }

  Future<void> save() async {
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble('dangerM', dangerM);
    await p.setDouble('warnM', warnM);
    await p.setDouble('hfov', hfov);
    await p.setDouble('laneHalf', laneHalf);
    await p.setDouble('minConf', minConf);
    await p.setDouble('minConfMotorcycle', minConfMotorcycle);
    await p.setBool('beep', beep);
    await p.setBool('includePeople', includePeople);
    await p.setBool('wakelock', wakelock);
    await p.setInt('detectionIntervalFrames', detectionIntervalFrames);
  }
}

class Alert {
  const Alert(this.status, [this.name, this.dist]);
  final String status;
  final String? name;
  final double? dist;

  @override
  bool operator ==(Object other) =>
      other is Alert &&
      other.status == status &&
      other.name == name &&
      other.dist?.round() == dist?.round();

  @override
  int get hashCode => Object.hash(status, name, dist?.round());
}

class Engine {
  Engine(this.s);
  final Settings s;
  int _streak = 0;

  double distance(String name, Rect box, bool portrait) {
    final real = sizes[name]!;
    final f = 0.5 / math.tan(s.hfov * math.pi / 360);
    final wRel = portrait ? 1 / frameAspect : 1.0;
    final hRel = portrait ? 1.0 : 1 / frameAspect;
    final dw = real[0] * f / math.max(box.width * wRel, 1e-6);
    final dh = real[1] * f / math.max(box.height * hRel, 1e-6);
    // Motor lebih sempit: pakai min() agar cukup satu dimensi dekat → dianggap dekat
    return name == 'motorcycle' ? math.min(dw, dh) : math.max(dw, dh);
  }

  Alert evaluate(List<YOLOResult> results, {required bool portrait}) {
    final classes = {...vehicles, if (s.includePeople) ...people};
    String? name;
    double? nearest;
    for (final r in results) {
      final conf = r.className == 'motorcycle' ? s.minConfMotorcycle : s.minConf;
      if (r.confidence < conf || !classes.contains(r.className)) continue;
      final box = r.normalizedBox;
      if ((box.center.dx - 0.5).abs() > s.laneHalf) continue;
      final d = distance(r.className, box, portrait);
      if (nearest == null || d < nearest) {
        nearest = d;
        name = r.className;
      }
    }
    if (nearest == null) {
      _streak = 0;
      return const Alert('AMAN');
    }
    final danger = nearest < s.dangerM;
    _streak = danger ? _streak + 1 : 0;
    if (danger && _streak >= alertFrames) return Alert('BAHAYA', name, nearest);
    if (nearest < math.max(s.warnM, s.dangerM)) return Alert('WASPADA', name, nearest);
    return Alert('AMAN', name, nearest);
  }
}

class History {
  static const _key = 'history';

  static Future<List<Map<String, dynamic>>> read() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_key) ?? [])
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }

  static Future<void> add(String name, double dist) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key) ?? [];
    list.insert(
      0,
      jsonEncode({'t': DateTime.now().toIso8601String(), 'n': name, 'd': dist.round()}),
    );
    await p.setStringList(_key, list.take(100).toList());
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}



