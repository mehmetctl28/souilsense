import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';

class SensorPairingCard extends StatefulWidget {
  final String sensorId;
  const SensorPairingCard({super.key, required this.sensorId});
  @override
  State<SensorPairingCard> createState() => _SensorPairingCardState();
}

class _SensorPairingCardState extends State<SensorPairingCard> {
  final _code = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sensors = context.watch<SensorProvider>();
    final error = sensors.sensorAccessErrors[widget.sensorId];
    if (!sensors.isHardwareMode) {
      return const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
              'Simülasyon: ölçümler, görevler ve sulama yerelde tutulur.'));
    }
    final invalid =
        sensors.getSensor(widget.sensorId)?.isValidMeasurement == false;
    if (error == null && !invalid) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      Text(error ?? 'Ölçüm eksik veya geçersiz. Otomatik sulama başlatılmaz.',
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (error != null && !sensors.isSensorPaired(widget.sensorId)) ...[
        TextField(
            controller: _code,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration:
                const InputDecoration(labelText: 'Cihaz eşleştirme kodu')),
        Wrap(spacing: 8, children: [
          FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final paired =
                          await sensors.pairSensor(widget.sensorId, _code.text);
                      if (!context.mounted) return;
                      setState(() => _busy = false);
                      if (paired) _code.clear();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(paired
                              ? 'Cihaz eşleştirildi.'
                              : 'Eşleştirme tamamlanamadı. Kodu kontrol edin.')));
                    },
              child: Text(_busy ? 'Eşleştiriliyor' : 'Cihazı eşleştir')),
          TextButton(
              onPressed:
                  _busy ? null : () => sensors.retrySensor(widget.sensorId),
              child: const Text('Yeniden dene')),
        ]),
      ],
    ]);
  }
}
