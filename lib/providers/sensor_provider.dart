import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';

class PumpCommandState {
  final bool requestedState;
  final bool actualState;
  final bool autoWatering;
  final int maxDurationSeconds;
  final int updatedAt;
  final bool timedOut;

  const PumpCommandState({
    this.requestedState = false,
    this.actualState = false,
    this.autoWatering = false,
    this.maxDurationSeconds = 15,
    this.updatedAt = 0,
    this.timedOut = false,
  });

  bool get isPendingConfirmation => requestedState != actualState;

  factory PumpCommandState.fromMap(Map<dynamic, dynamic> map) {
    return PumpCommandState(
      requestedState: map['requestedState'] == true,
      actualState: map['actualState'] == true,
      autoWatering: map['autoWatering'] == true,
      maxDurationSeconds: SensorData.parseSafeInt(map['maxDurationSeconds'], fallback: 15),
      updatedAt: SensorData.normalizeTimestamp(map['updatedAt']),
      timedOut: map['timedOut'] == true,
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
  static const String _hardwareModePrefKey = 'is_hardware_mode';
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  final Map<String, SensorData> _hardwareSensors = {};
  final Map<String, SensorData> _simulatedSensors = {};
  final Map<String, PumpCommandState> _pumpStates = {};
  final Map<String, SensorConfig> _sensorConfigs = {};
  final Map<String, List<double>> _moistureHistory = {};
  final Map<String, List<TimelineEvent>> _timelines = {};
  final Map<String, Timer> _pumpWatchdogTimers = {};

  bool _isHardwareMode = false;
  bool get isHardwareMode => _isHardwareMode;

  Map<String, SensorData> get sensors =>
      _isHardwareMode ? _hardwareSensors : {..._simulatedSensors, ..._hardwareSensors};

  StreamSubscription<DatabaseEvent>? _sensorsSubscription;
  StreamSubscription<DatabaseEvent>? _pumpSubscription;
  StreamSubscription<DatabaseEvent>? _configSubscription;

  SensorProvider() {
    _loadModePreference();
    _listenToSensors();
    _listenToPumpCommands();
    _listenToSensorConfigs();
  }

  Future<void> _loadModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isHardwareMode = prefs.getBool(_hardwareModePrefKey) ?? false;
    notifyListeners();
  }

  Future<void> setHardwareMode(bool enabled) async {
    _isHardwareMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hardwareModePrefKey, enabled);
  }

  void _listenToSensors() {
    _sensorsSubscription = _db.child('sensors').onValue.listen((event) {
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final sensorId = key.toString();
            final Map<dynamic, dynamic> currentMap =
                (value['current'] is Map) ? value['current'] as Map : value;
            final parsed = SensorData.fromMap(sensorId, currentMap);
            _hardwareSensors[sensorId] = parsed;

            if (value['history'] is Map) {
              final historyMap = value['history'] as Map;
              final sortedKeys = historyMap.keys.map((k) => k.toString()).toList()..sort();
              final List<double> points = [];
              for (final tsKey in sortedKeys) {
                final entry = historyMap[tsKey];
                if (entry is Map && entry['moisture'] != null) {
                  points.add(SensorData.parseSafeDouble(entry['moisture'], fallback: parsed.moisture));
                }
              }
              if (points.isNotEmpty) {
                _moistureHistory[sensorId] =
                    points.length > 7 ? points.sublist(points.length - 7) : points;
              }
            } else {
              final list = _moistureHistory.putIfAbsent(sensorId, () => []);
              if (list.isEmpty || (list.last - parsed.moisture).abs() >= 0.5) {
                list.add(parsed.moisture);
                if (list.length > 7) list.removeAt(0);
              }
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
            final sId = key.toString();
            final state = PumpCommandState.fromMap(value);
            _pumpStates[sId] = state;

            // ESP32 pompayı açtığını onayladıysa Watchdog zamanlayıcısını iptal et
            if (state.actualState == state.requestedState) {
              _pumpWatchdogTimers[sId]?.cancel();
            }
          }
        });
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("Pompa durumu dinleme uyarısı: $error");
    });
  }

  void _listenToSensorConfigs() {
    _configSubscription = _db.child('sensorConfigs').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            final sId = key.toString();
            _sensorConfigs[sId] = SensorConfig.fromMap(sId, value);
          }
        });
        notifyListeners();
      }
    }, onError: (_) {});
  }

  SensorData? getSensor(String sensorId) {
    if (sensorId.isEmpty) return null;
    if (_isHardwareMode) {
      return _hardwareSensors[sensorId];
    }
    return _hardwareSensors[sensorId] ?? _simulatedSensors[sensorId];
  }

  SensorConfig getSensorConfig(String sensorId) {
    return _sensorConfigs[sensorId] ?? SensorConfig(sensorId: sensorId);
  }

  Future<void> saveSensorConfig(SensorConfig config) async {
    _sensorConfigs[config.sensorId] = config;
    notifyListeners();
    try {
      await _db.child('sensorConfigs').child(config.sensorId).set(config.toMap());
    } catch (e) {
      debugPrint("Kalibrasyon kaydı uyarısı: $e");
    }
  }

  PumpCommandState getPumpState(String sensorId, {bool fallbackPumpOn = false}) {
    return _pumpStates[sensorId] ??
        PumpCommandState(requestedState: fallbackPumpOn, actualState: false);
  }

  List<double> getMoistureHistory(String sensorId, double currentMoisture) {
    final list = _moistureHistory[sensorId];
    if (list != null && list.length >= 2) return List<double>.from(list);
    return [currentMoisture, currentMoisture];
  }

  // Kuruma hızı analizi: Kritik nem eşiğine tahmini kaç saat kaldığını hesaplar
  String estimateTimeUntilCritical(String sensorId, double currentMoisture, int minMoisture) {
    if (currentMoisture <= minMoisture) {
      return "Kritik eşiğin altında (Hemen sulanmalı)";
    }
    final history = _moistureHistory[sensorId];
    if (history == null || history.length < 2) {
      return "Tahmin için sensör geçmişi toplanıyor";
    }

    // Son ölçümler arasındaki ortalama düşüş hızı
    final double first = history.first;
    final double last = history.last;
    final double drop = first - last;

    if (drop <= 0.5) {
      return "Nem dengeli (Hızlı kayıp yok)";
    }

    final double hourlyDropRate = (drop / history.length).clamp(0.3, 8.0);
    final int hoursRemaining = ((currentMoisture - minMoisture) / hourlyDropRate).round();
    return "Kuruma hızı: ~%${hourlyDropRate.toStringAsFixed(1)}/ölçüm • Tahmini $hoursRemaining saat sonra sulama";
  }

  List<TimelineEvent> getTimeline(String sensorId, double currentMoisture) {
    final existing = _timelines[sensorId];
    if (existing != null && existing.isNotEmpty) return existing;
    final sensor = getSensor(sensorId);
    if (sensor == null) return [];
    return [
      TimelineEvent(
        sensorId: sensorId,
        title: "Son Telemetri Paketi",
        subtitle: "Nem: %${sensor.moisture.toInt()} • Sıcaklık: ${sensor.temperature.toStringAsFixed(1)}°C",
        timestamp: sensor.lastUpdate,
        type: 'sensor',
      ),
    ];
  }

  List<TimelineEvent> getAllGardenTimeline() {
    final List<TimelineEvent> all = [];
    _timelines.forEach((_, list) => all.addAll(list));
    if (all.isEmpty) {
      sensors.forEach((id, s) {
        all.add(
          TimelineEvent(
            sensorId: id,
            title: "Sensör ($id) Durumu",
            subtitle: "Nem: %${s.moisture.toInt()} • Sıcaklık: ${s.temperature.toStringAsFixed(1)}°C",
            timestamp: s.lastUpdate,
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

  // Pompa Komutu + 20 Saniyelik Donanım Watchdog Koruması
  Future<void> requestPumpState({
    required String sensorId,
    required bool requestedState,
    int maxDurationSeconds = 15,
    bool? autoWatering,
  }) async {
    if (sensorId.isEmpty) return;

    final prev = _pumpStates[sensorId] ?? const PumpCommandState();
    final sensor = getSensor(sensorId);

    if (autoWatering == true && (sensor == null || !sensor.isOnline)) {
      _addLocalTimelineEvent(
        sensorId,
        "Otomatik Sulama Engellendi ($sensorId)",
        "Sensör verisi güncel olmadığı için güvenlik kilidi devreye girdi.",
        'alert',
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final bool nextActualState = _isHardwareMode ? prev.actualState : requestedState;

    final updated = PumpCommandState(
      requestedState: requestedState,
      actualState: nextActualState,
      autoWatering: autoWatering ?? prev.autoWatering,
      maxDurationSeconds: maxDurationSeconds,
      updatedAt: now,
      timedOut: false,
    );

    _pumpStates[sensorId] = updated;

    // Donanım modunda pompa açma komutu verildiyse 20 sn Watchdog başlat
    _pumpWatchdogTimers[sensorId]?.cancel();
    if (_isHardwareMode && requestedState) {
      _pumpWatchdogTimers[sensorId] = Timer(const Duration(seconds: 20), () async {
        final currentState = _pumpStates[sensorId];
        if (currentState != null && currentState.requestedState && !currentState.actualState) {
          // ESP32 20 saniye içinde yanıt vermedi; komutu güvenlik için geri çek!
          _pumpStates[sensorId] = PumpCommandState(
            requestedState: false,
            actualState: false,
            autoWatering: currentState.autoWatering,
            maxDurationSeconds: maxDurationSeconds,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            timedOut: true,
          );
          _addLocalTimelineEvent(
            sensorId,
            "Pompa Komutu Zaman Aşımı ($sensorId)",
            "ESP32 20 sn içinde onay vermediği için komut güvenlik amacıyla iptal edildi.",
            'alert',
          );
          try {
            await _db.child('pumpCommands').child(sensorId).update({
              'requestedState': false,
              'timedOut': true,
            });
          } catch (_) {}
        }
      });
    }

    if (!_isHardwareMode && requestedState) {
      final current = getSensor(sensorId);
      final nextMoisture = ((current?.moisture ?? 30.0) + 20.0).clamp(0.0, 95.0);
      await simulateSensorReading(
        sensorId: sensorId,
        moisture: nextMoisture,
        temperature: current?.temperature ?? 24.0,
        light: current?.light ?? 65.0,
      );
    }

    _addLocalTimelineEvent(
      sensorId,
      requestedState ? "Pompa Açma İsteği ($sensorId)" : "Pompa Durdurma İsteği ($sensorId)",
      _isHardwareMode
          ? "ESP32 onayı bekleniyor (20sn Watchdog koruması aktif)."
          : "Simülasyon modunda pompa çalıştırıldı.",
      'watering',
    );

    try {
      await _db.child('pumpCommands').child(sensorId).update({
        'requestedState': requestedState,
        'autoWatering': updated.autoWatering,
        'maxDurationSeconds': maxDurationSeconds,
        'updatedAt': now,
        'timedOut': false,
      });
    } catch (e) {
      debugPrint("Firebase pumpCommands yazma uyarısı: $e");
    }
  }

  Future<void> simulateSensorReading({
    required String sensorId,
    required double moisture,
    required double temperature,
    required double light,
  }) async {
    if (sensorId.isEmpty || _isHardwareMode) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final simulated = SensorData(
      sensorId: sensorId,
      moisture: moisture,
      temperature: temperature,
      light: light,
      lastUpdate: now,
    );

    _simulatedSensors[sensorId] = simulated;
    final history = _moistureHistory.putIfAbsent(sensorId, () => []);
    history.add(moisture);
    if (history.length > 7) history.removeAt(0);

    _addLocalTimelineEvent(
      sensorId,
      "Simülasyon Ölçümü ($sensorId)",
      "Nem: %${moisture.toInt()} • Sıcaklık: ${temperature.toStringAsFixed(1)}°C • Işık: %${light.toInt()}",
      'sensor',
    );
  }

  Future<void> ensureSensorExists(String sensorId, {double initialMoisture = 50.0}) async {
    if (sensorId.isEmpty || _isHardwareMode) return;
    if (_hardwareSensors.containsKey(sensorId) || _simulatedSensors.containsKey(sensorId)) {
      return;
    }
    await simulateSensorReading(
      sensorId: sensorId,
      moisture: initialMoisture,
      temperature: 24.0,
      light: 65.0,
    );
  }

  @override
  void dispose() {
    for (final timer in _pumpWatchdogTimers.values) {
      timer.cancel();
    }
    _sensorsSubscription?.cancel();
    _pumpSubscription?.cancel();
    _configSubscription?.cancel();
    super.dispose();
  }
}