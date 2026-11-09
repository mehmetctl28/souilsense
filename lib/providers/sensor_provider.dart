import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/sensor_data.dart';

class PumpCommandState {
  final bool requestedState;
  final bool actualState;
  final bool autoWatering;
  final int maxDurationSeconds;
  final int updatedAt;

  const PumpCommandState({
    this.requestedState = false,
    this.actualState = false,
    this.autoWatering = false,
    this.maxDurationSeconds = 15,
    this.updatedAt = 0,
  });

  factory PumpCommandState.fromMap(Map<dynamic, dynamic> map) {
    return PumpCommandState(
      requestedState: map['requestedState'] == true,
      actualState: map['actualState'] == true,
      autoWatering: map['autoWatering'] == true,
      maxDurationSeconds: (map['maxDurationSeconds'] ?? 15).toInt(),
      updatedAt: (map['updatedAt'] ?? 0).toInt(),
    );
  }
}

class TimelineEvent {
  final String sensorId;
  final String title;
  final String subtitle;
  final int timestamp;
  final String type; // watering, alert, sensor

  const TimelineEvent({
    required this.sensorId,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.type = 'sensor',
  });
}

class SensorProvider extends ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  final Map<String, SensorData> _sensors = {};
  final Map<String, PumpCommandState> _pumpStates = {};
  final Map<String, List<double>> _moistureHistory = {};
  final Map<String, List<TimelineEvent>> _timelines = {};

  Map<String, SensorData> get sensors => _sensors;

  StreamSubscription<DatabaseEvent>? _sensorsSubscription;
  StreamSubscription<DatabaseEvent>? _pumpSubscription;

  SensorProvider() {
    _listenToSensors();
    _listenToPumpCommands();
  }

  void _listenToSensors() {
    _sensorsSubscription = _db.child('sensors').onValue.listen((event) {
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final sensorId = key.toString();
            final parsed = SensorData.fromMap(sensorId, value);
            _sensors[sensorId] = parsed;

            final history = _moistureHistory.putIfAbsent(
              sensorId,
              () => [58, 54, 49, 44, 40, parsed.moisture],
            );
            if (history.isEmpty || (history.last - parsed.moisture).abs() >= 1.0) {
              history.add(parsed.moisture);
              if (history.length > 7) history.removeAt(0);
            }
          }
        });
      }
      notifyListeners();
    }, onError: (error) {
      debugPrint("Sensör dinleme uyarısı: $error");
    });
  }

  void _listenToPumpCommands() {
    _pumpSubscription = _db.child('pumpCommands').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            _pumpStates[key.toString()] = PumpCommandState.fromMap(value);
          }
        });
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("Pompa durumu dinleme uyarısı: $error");
    });
  }

  SensorData? getSensor(String sensorId) {
    if (sensorId.isEmpty) return null;
    return _sensors[sensorId];
  }

  PumpCommandState getPumpState(String sensorId, {bool fallbackPumpOn = false}) {
    return _pumpStates[sensorId] ??
        PumpCommandState(requestedState: fallbackPumpOn, actualState: false);
  }

  List<double> getMoistureHistory(String sensorId, double currentMoisture) {
    final list = _moistureHistory[sensorId];
    if (list != null && list.length >= 2) return list;
    return [
      (currentMoisture + 12).clamp(10, 95),
      (currentMoisture + 8).clamp(10, 95),
      (currentMoisture + 4).clamp(10, 95),
      (currentMoisture - 3).clamp(10, 95),
      (currentMoisture - 6).clamp(10, 95),
      (currentMoisture - 2).clamp(10, 95),
      currentMoisture,
    ];
  }

  List<TimelineEvent> getTimeline(String sensorId, double currentMoisture) {
    final existing = _timelines[sensorId];
    if (existing != null && existing.isNotEmpty) return existing;
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      TimelineEvent(
        sensorId: sensorId,
        title: "Canlı Telemetri Ölçümü",
        subtitle: "Toprak nemi %${currentMoisture.toInt()} olarak kaydedildi.",
        timestamp: now,
        type: 'sensor',
      ),
      TimelineEvent(
        sensorId: sensorId,
        title: "Sensör Eşleşmesi Doğrulandı",
        subtitle: "ESP32 düğümü ($sensorId) izlemeye alındı.",
        timestamp: now - 3600 * 1000 * 3,
        type: 'sensor',
      ),
    ];
  }

  // Tüm bahçenin bakım ve sulama geçmişini tek listede toplar
  List<TimelineEvent> getAllGardenTimeline() {
    final List<TimelineEvent> all = [];
    _timelines.forEach((_, list) => all.addAll(list));
    if (all.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _sensors.forEach((id, s) {
        all.add(
          TimelineEvent(
            sensorId: id,
            title: "Sensör ($id) Veri Akışı",
            subtitle: "Nem: %${s.moisture.toInt()} • Sıcaklık: ${s.temperature.toStringAsFixed(1)}°C",
            timestamp: s.lastUpdate > 0 ? s.lastUpdate : now,
            type: 'sensor',
          ),
        );
      });
    }
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  void _addLocalTimelineEvent(String sensorId, String title, String subtitle, String type) {
    final list = _timelines.putIfAbsent(sensorId, () => []);
    list.insert(
      0,
      TimelineEvent(
        sensorId: sensorId,
        title: title,
        subtitle: subtitle,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: type,
      ),
    );
    notifyListeners();
  }

  Future<void> requestPumpState({
    required String sensorId,
    required bool requestedState,
    int maxDurationSeconds = 15,
    bool? autoWatering,
  }) async {
    if (sensorId.isEmpty) return;

    final prev = _pumpStates[sensorId] ?? const PumpCommandState();
    final now = DateTime.now().millisecondsSinceEpoch;

    final updated = PumpCommandState(
      requestedState: requestedState,
      actualState: requestedState, // Simülasyon modunda pompayı aktif gösterir
      autoWatering: autoWatering ?? prev.autoWatering,
      maxDurationSeconds: maxDurationSeconds,
      updatedAt: now,
    );

    _pumpStates[sensorId] = updated;

    // Sulama açıldıysa sensör nemini de kademeli artırarak gerçekçi geri bildirim ver
    if (requestedState) {
      final current = _sensors[sensorId];
      final nextMoisture = ((current?.moisture ?? 30.0) + 25.0).clamp(0.0, 95.0);
      await simulateSensorReading(
        sensorId: sensorId,
        moisture: nextMoisture,
        temperature: current?.temperature ?? 24.0,
        light: current?.light ?? 65.0,
      );
    }

    _addLocalTimelineEvent(
      sensorId,
      requestedState ? "Sulama Başlatıldı ($sensorId)" : "Sulama Durduruldu ($sensorId)",
      requestedState
          ? "Pompa $maxDurationSeconds sn güvenlik sınırıyla çalıştırıldı."
          : "Pompa kapatma komutu uygulandı.",
      'watering',
    );

    try {
      await _db.child('pumpCommands').child(sensorId).update({
        'requestedState': requestedState,
        'actualState': updated.actualState,
        'autoWatering': updated.autoWatering,
        'maxDurationSeconds': maxDurationSeconds,
        'updatedAt': now,
      });
    } catch (e) {
      debugPrint("Firebase pumpCommands yazma uyarısı: $e");
    }
  }

  // Uygulama içinden sensör değerlerini canlı test etme (ESP32 simülatörü)
  Future<void> simulateSensorReading({
    required String sensorId,
    required double moisture,
    required double temperature,
    required double light,
  }) async {
    if (sensorId.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = SensorData(
      sensorId: sensorId,
      moisture: moisture,
      temperature: temperature,
      light: light,
      lastUpdate: now,
    );

    _sensors[sensorId] = updated;
    final history = _moistureHistory.putIfAbsent(sensorId, () => [50, 48, 45, 42]);
    history.add(moisture);
    if (history.length > 7) history.removeAt(0);

    _addLocalTimelineEvent(
      sensorId,
      "Telemetri Güncellendi ($sensorId)",
      "Nem: %${moisture.toInt()} • Sıcaklık: ${temperature.toStringAsFixed(1)}°C • Işık: %${light.toInt()}",
      'sensor',
    );

    try {
      await _db.child('sensors').child(sensorId).set(updated.toMap());
    } catch (e) {
      debugPrint("Simülasyon verisi yerel belleğe yazıldı: $e");
    }
  }

  Future<void> ensureSensorExists(String sensorId, {double initialMoisture = 50.0}) async {
    if (sensorId.isEmpty || _sensors.containsKey(sensorId)) return;
    await simulateSensorReading(
      sensorId: sensorId,
      moisture: initialMoisture,
      temperature: 24.0,
      light: 65.0,
    );
  }

  @override
  void dispose() {
    _sensorsSubscription?.cancel();
    _pumpSubscription?.cancel();
    super.dispose();
  }
}