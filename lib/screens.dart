import 'package:material_ui/material_ui.dart';

import 'core.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen(this.s, this.onTestBeep, {super.key});
  final Settings s;
  final VoidCallback onTestBeep;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Settings get s => widget.s;

  Widget slider(String title, double value, double min, double max, int div,
      String Function(double) fmt, void Function(double) set, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title: ${fmt(value)}'),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: div,
            onChanged: (v) => setState(() => set(v)),
            onChangeEnd: (_) => s.save(),
          ),
          if (hint != null)
            Text(hint, style: const TextStyle(fontSize: 12, color: Colors.white60)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Suara beep'),
            value: s.beep,
            onChanged: (v) => setState(() {
              s.beep = v;
              s.save();
            }),
          ),
          SwitchListTile(
            title: const Text('Sertakan pejalan kaki & pesepeda'),
            value: s.includePeople,
            onChanged: (v) => setState(() {
              s.includePeople = v;
              s.save();
            }),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onTestBeep,
              icon: const Icon(Icons.volume_up),
              label: const Text('Tes beep'),
            ),
          ),
          const Divider(),
          slider('Jarak bahaya (beep)', s.dangerM, 3, 30, 27, (v) => '${v.round()} m',
              (v) => s.dangerM = v),
          slider('Jarak waspada', s.warnM, 10, 60, 50, (v) => '${v.round()} m',
              (v) => s.warnM = v),
          slider('Lebar jalur tengah', s.laneHalf * 2, 0.1, 0.8, 14,
              (v) => '${(v * 100).round()}% lebar layar', (v) => s.laneHalf = v / 2),
          slider('Kepercayaan minimum', s.minConf, 0.2, 0.8, 12,
              (v) => '${(v * 100).round()}%', (v) => s.minConf = v),
          slider('Sudut pandang kamera', s.hfov, 40, 140, 100, (v) => '${v.round()}°',
              (v) => s.hfov = v,
              hint: 'Kalibrasi: arahkan ke kendaraan yang jaraknya kamu tahu, ubah '
                  'sampai angka meter di layar cocok. Sudut lebih kecil = jarak terbaca '
                  'lebih jauh.'),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> future = History.read();

  String two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat peringatan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await History.clear();
              setState(() => future = History.read());
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('Belum ada peringatan'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final t = DateTime.parse(items[i]['t'] as String);
              final name = labelsId[items[i]['n']] ?? items[i]['n'];
              return ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.red),
                title: Text('$name ±${items[i]['d']} m'),
                subtitle: Text(
                  '${t.day}/${t.month}/${t.year}  ${two(t.hour)}:${two(t.minute)}:${two(t.second)}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
