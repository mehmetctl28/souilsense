import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';
import '../models/plant.dart';

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

  factory TimelineEvent.fromMap(String sensorId, Map<dynamic, dynamic> map, {String? forcedType}) {
    return TimelineEvent(
      sensorId: sensorId,
      title: (map['title'] ?? '').toString(),
      subtitle: (map['subtitle'] ?? '').toString(),
      timestamp: SensorData.parseSafeInt(
        map['timestamp'],
        fallback: DateTime.now().millisecondsSinceEpoch,
      ),
      type: forcedType ?? (map['type'] ?? 'sensor').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'timestamp': timestamp,
      'type': type,
    };
  }
}

class SensorProvider extends ChangeNotifier {
  static const String _hardwareModePrefKey = 'is_hardware_mode';
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, SensorData> _hardwareSensors = {};
  final Map<String, SensorData> _simulatedSensors = {};
  final Map<String, PumpCommandState> _pumpStates = {};
  final Map<String, SensorConfig> _sensorConfigs = {};

  // 5.2: 3 ayrı kalıcı geçmiş katmanı (sensorHistory, wateringEvents, alerts)
  final Map<String, List<TelemetryPoint>> _telemetryHistory = {};
  final Map<String, List<TimelineEvent>> _wateringEvents = {};
  final Map<String, List<TimelineEvent>> _alertEvents = {};

  final Map<String, WateringEffectivenessReport> _wateringReports = {};
  final Map<String, double> _preWateringMoisture = {};
  final Map<String, Timer> _pumpWatchdogTimers = {};

  final Map<String, StreamSubscription<DatabaseEvent>> _sensorSubs = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _pumpSubs = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _configSubs = {};
  Map<String, Plant> _authorizedPlantsBySensor = {};

  final Map<String, int> _lastAutoWateringTimestamp = {};
  final Map<String, int> _dailyAutoWateringCount = {};

  // 5.3: Gerçek bildirim akışı (Notifications açıkken arayüzde anlık uyarı tetikler)
  final StreamController<TimelineEvent> _alertStreamController =
      StreamController<TimelineEvent>.broadcast();
  Stream<TimelineEvent> get alertStream => _alertStreamController.stream;

  bool _isHardwareMode;
  bool _notificationsEnabled = true;
  int _maxPumpSeconds;
  int _offlineTimeoutMinutes;

  bool get isHardwareMode => _isHardwareMode;
  bool get notificationsEnabled => _notificationsEnabled;
  int get maxPumpSeconds => _maxPumpSeconds;
  int get offlineTimeoutMinutes => _offlineTimeoutMinutes;

  Map<String, SensorData> get sensors =>
      _isHardwareMode ? _hardwareSensors : {..._hardwareSensors, ..._simulatedSensors};

  int get connectedHardwareSensorCount => _hardwareSensors.values
      .where((s) => s.isOnlineWithThreshold(_offlineTimeoutMinutes))
      .length;

  int? get lastHardwareUpdateTimestamp {
    if (_hardwareSensors.isEmpty) return null;
    int latest = 0;
    for (final s in _hardwareSensors.values) {
      if (s.lastUpdate > latest) latest = s.lastUpdate;
    }
    return latest > 0 ? latest : null;
  }

  StreamSubscription<DatabaseEvent>? _wateringHistorySub;
  StreamSubscription<DatabaseEvent>? _alertsHistorySub;
  StreamSubscription<DatabaseEvent>? _userSensorHistorySub;
  StreamSubscription<User?>? _authSubscription;

  SensorProvider({
    bool initialHardwareMode = false,
    int initialMaxPumpSeconds = 15,
    int initialOfflineMinutes = 30,
  })  : _isHardwareMode = initialHardwareMode,
        _maxPumpSeconds = initialMaxPumpSeconds,
        _offlineTimeoutMinutes = initialOfflineMinutes {
    reloadSafetySettings();
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToSeparatedUserHistories(user.uid);
      } else {
        _clearAllSubscriptions();
      }
    });
  }

  void _clearAllSubscriptions() {
    for (final sub in _sensorSubs.values) {
      sub.cancel();
    }
    for (final sub in _pumpSubs.values) {
      sub.cancel();
    }
    for (final sub in _configSubs.values) {
      sub.cancel();
    }
    _sensorSubs.clear();
    _pumpSubs.clear();
    _configSubs.clear();
    _wateringHistorySub?.cancel();
    _alertsHistorySub?.cancel();
    _userSensorHistorySub?.cancel();
    _authorizedPlantsBySensor.clear();
    _hardwareSensors.clear();
    _simulatedSensors.clear();
    _pumpStates.clear();
    _wateringEvents.clear();
    _alertEvents.clear();
    _telemetryHistory.clear();
    notifyListeners();
  }

  // 5.2: Firebase'de wateringEvents, alerts ve sensorHistory düğümlerini ayrı ayrı dinler
  void _listenToSeparatedUserHistories(String userId) {
    _wateringHistorySub?.cancel();
    _alertsHistorySub?.cancel();
    _userSensorHistorySub?.cancel();

    final userRef = _db.child('users').child(userId);

    _wateringHistorySub = userRef.child('wateringEvents').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        data.forEach((sensorKey, evMap) {
          if (evMap is Map) {
            final sId = sensorKey.toString();
            final List<TimelineEvent> list = [];
            evMap.forEach((_, val) {
              if (val is Map) {
                list.add(TimelineEvent.fromMap(sId, val, forcedType: 'watering'));
              }
            });
            list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            _wateringEvents[sId] = list;
          }
        });
        notifyListeners();
      }
    }, onError: (_) {});

    _alertsHistorySub = userRef.child('alerts').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        data.forEach((sensorKey, evMap) {
          if (evMap is Map) {
            final sId = sensorKey.toString();
            final List<TimelineEvent> list = [];
            evMap.forEach((_, val) {
              if (val is Map) {
                list.add(TimelineEvent.fromMap(sId, val, forcedType: 'alert'));
              }
            });
            list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            _alertEvents[sId] = list;
          }
        });
        notifyListeners();
      }
    }, onError: (_) {});

    _userSensorHistorySub = userRef.child('sensorHistory').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        data.forEach((sensorKey, tsMap) {
          if (tsMap is Map) {
            final sId = sensorKey.toString();
            final List<TelemetryPoint> points = [];
            tsMap.forEach((tsKey, val) {
              final ts = SensorData.normalizeTimestamp(tsKey);
              if (val is Map && ts > 0) {
                points.add(TelemetryPoint.fromMap(ts, val));
              }
            });
            points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            if (points.isNotEmpty) {
              _telemetryHistory[sId] =
                  points.length > 30 ? points.sublist(points.length - 30) : points;
            }
          }
        });
        notifyListeners();
      }
    }, onError: (_) {});
  }

  void syncAuthorizedPlants(List<Plant> userPlants) {
    final user = _auth.currentUser;
    if (user == null) return;

    final Map<String, Plant> nextMap = {};
    for (final plant in userPlants) {
      final sId = plant.sensorId.trim();
      if (sId.isNotEmpty) {
        nextMap[sId] = plant;
      }
    }
    _authorizedPlantsBySensor = nextMap;

    final removedIds = _sensorSubs.keys.where((id) => !nextMap.containsKey(id)).toList();
    for (final id in removedIds) {
      _sensorSubs.remove(id)?.cancel();
      _pumpSubs.remove(id)?.cancel();
      _configSubs.remove(id)?.cancel();
      _hardwareSensors.remove(id);
      _simulatedSensors.remove(id);
    }

    for (final entry in nextMap.entries) {
      final sId = entry.key;
      final plant = entry.value;
      if (!_sensorSubs.containsKey(sId)) {
        _claimAndSubscribeSensor(user.uid, sId, plant);
      }
    }
  }

  Future<void> _claimAndSubscribeSensor(String uid, String sensorId, Plant plant) async {
    try {
      await _db.child('sensorOwners').child(sensorId).set(uid);
      await _db.child('sensorConfigs').child(sensorId).update({
        'ownerUid': uid,
        'minMoisture': plant.minMoisture,
        'maxMoisture': plant.maxMoisture,
        'maxPumpSeconds': _maxPumpSeconds,
        'hardwareMode': _isHardwareMode,
      });
    } catch (_) {}

    _configSubs[sensorId] = _db.child('sensorConfigs').child(sensorId).onValue.listen((event) {
      if (event.snapshot.value is Map) {
        _sensorConfigs[sensorId] =
            SensorConfig.fromMap(sensorId, event.snapshot.value as Map);
        notifyListeners();
      }
    }, onError: (_) {});

    _pumpSubs[sensorId] = _db.child('pumpCommands').child(sensorId).onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final state = PumpCommandState.fromMap(event.snapshot.value as Map);
        _pumpStates[sensorId] = state;
        if (state.actualState == state.requestedState) {
          _pumpWatchdogTimers[sensorId]?.cancel();
        }
        notifyListeners();
      }
    }, onError: (_) {});

    _sensorSubs[sensorId] = _db.child('sensors').child(sensorId).onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        _onSingleSensorData(sensorId, value);
      }
    }, onError: (_) {});
  }

  void _onSingleSensorData(String sensorId, Map<dynamic, dynamic> value) {
    final config = _sensorConfigs[sensorId];
    final Map<dynamic, dynamic> currentMap =
        (value['current'] is Map) ? value['current'] as Map : value;
    final parsed = SensorData.fromMap(
      sensorId,
      currentMap,
      config: config,
      isSimulated: false,
    );
    _hardwareSensors[sensorId] = parsed;

    if (_preWateringMoisture.containsKey(sensorId)) {
      final pre = _preWateringMoisture.remove(sensorId)!;
      final report = WateringEffectivenessReport(
        sensorId: sensorId,
        preMoisture: pre,
        postMoisture: parsed.moisture,
        timestamp: parsed.lastUpdate,
      );
      _wateringReports[sensorId] = report;

      if (!report.isEffective) {
        _recordSeparatedEvent(
          sensorId,
          "Sulama Sonrası Düşük Etki ($sensorId)",
          "Sulama öncesi %${pre.toInt()} → sonrası %${parsed.moisture.toInt()}. Su deposunu veya hortumu kontrol edin.",
          'alert',
        );
      }
    }

    final point = TelemetryPoint(
      timestamp: parsed.lastUpdate,
      moisture: parsed.moisture,
      temperature: parsed.temperature,
      light: parsed.light,
    );
    _appendAndPersistHistoryPoint(sensorId, point);

    final linkedPlant = _authorizedPlantsBySensor[sensorId];
    if (linkedPlant != null) {
      _checkAndTriggerAutoWatering(linkedPlant, parsed);
    }

    notifyListeners();
  }

  Future<void> _appendAndPersistHistoryPoint(String sensorId, TelemetryPoint point) async {
    final list = _telemetryHistory.putIfAbsent(sensorId, () => []);
    final bool shouldSave = list.isEmpty ||
        (list.last.moisture - point.moisture).abs() >= 1.0 ||
        (point.timestamp - list.last.timestamp) >= 5 * 60 * 1000;

    if (!shouldSave) return;

    list.add(point);
    if (list.length > 30) list.removeAt(0);

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _db
            .child('users')
            .child(uid)
            .child('sensorHistory')
            .child(sensorId)
            .child(point.timestamp.toString())
            .set(point.toMap());
      } catch (_) {}
    }
  }

  // 5.2 & 5.3: Olayları wateringEvents ve alerts düğümlerine ayrı ayrı yazar ve bildirim açıksa uyarı yayınlar
  Future<void> _recordSeparatedEvent(
    String sensorId,
    String title,
    String subtitle,
    String type,
  ) async {
    final event = TimelineEvent(
      sensorId: sensorId,
      title: title,
      subtitle: subtitle,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: type,
    );

    if (type == 'watering') {
      final list = _wateringEvents.putIfAbsent(sensorId, () => []);
      list.insert(0, event);
    } else if (type == 'alert') {
      final list = _alertEvents.putIfAbsent(sensorId, () => []);
      list.insert(0, event);
      if (_notificationsEnabled) {
        _alertStreamController.add(event);
      }
    }
    notifyListeners();

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final String nodeName = type == 'watering' ? 'wateringEvents' : 'alerts';
      try {
        await _db
            .child('users')
            .child(uid)
            .child(nodeName)
            .child(sensorId)
            .push()
            .set(event.toMap());
      } catch (_) {}
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }

  Future<void> triggerTestNotification() async {
    final event = TimelineEvent(
      sensorId: 'sistem',
      title: 'SoilSense Bildirim Testi Başarılı',
      subtitle: 'Kritik nem, çevrimdışı sensör ve pompa zaman aşımı uyarıları aktif.',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: 'alert',
    );
    _alertStreamController.add(event);
  }

  Future<void> updateSafetySettings({
    required int maxPumpSeconds,
    required int offlineTimeoutMinutes,
  }) async {
    _maxPumpSeconds = maxPumpSeconds;
    _offlineTimeoutMinutes = offlineTimeoutMinutes;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_pump_seconds', maxPumpSeconds);
    await prefs.setInt('offline_timeout_minutes', offlineTimeoutMinutes);

    for (final sId in _authorizedPlantsBySensor.keys) {
      try {
        await _db.child('sensorConfigs').child(sId).update({
          'maxPumpSeconds': maxPumpSeconds,
        });
      } catch (_) {}
    }
  }

  Future<void> reloadSafetySettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isHardwareMode = prefs.getBool(_hardwareModePrefKey) ?? false;
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    _maxPumpSeconds = prefs.getInt('max_pump_seconds') ?? 15;
    _offlineTimeoutMinutes = prefs.getInt('offline_timeout_minutes') ?? 30;
    notifyListeners();
  }

  Future<void> setHardwareMode(bool enabled) async {
    _isHardwareMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hardwareModePrefKey, enabled);

    for (final sId in _authorizedPlantsBySensor.keys) {
      try {
        await _db.child('sensorConfigs').child(sId).update({
          'hardwareMode': enabled,
        });
      } catch (_) {}
    }
  }

  SensorData? getSensor(String sensorId) {
    if (sensorId.isEmpty) return null;
    if (_isHardwareMode) {
      return _hardwareSensors[sensorId];
    }
    return _simulatedSensors[sensorId] ?? _hardwareSensors[sensorId];
  }

  bool isSensorOnline(String sensorId) {
    final s = getSensor(sensorId);
    return s != null && s.isOnlineWithThreshold(_offlineTimeoutMinutes);
  }

  SensorConfig getSensorConfig(String sensorId) {
    return _sensorConfigs[sensorId] ??
        SensorConfig(sensorId: sensorId, maxPumpSeconds: _maxPumpSeconds);
  }

  WateringEffectivenessReport? getWateringReport(String sensorId) {
    return _wateringReports[sensorId];
  }

  Future<void> saveSensorConfig(SensorConfig config) async {
    _sensorConfigs[config.sensorId] = config;
    notifyListeners();
    try {
      await _db.child('sensorConfigs').child(config.sensorId).update(config.toMap());
    } catch (_) {}
  }

  PumpCommandState getPumpState(String sensorId, {bool fallbackPumpOn = false}) {
    return _pumpStates[sensorId] ??
        PumpCommandState(
          requestedState: fallbackPumpOn,
          actualState: false,
          maxDurationSeconds: _maxPumpSeconds,
        );
  }

  List<TelemetryPoint> getTelemetryHistory(String sensorId) {
    return List<TelemetryPoint>.from(_telemetryHistory[sensorId] ?? const []);
  }

  List<double> getMoistureHistory(String sensorId, double currentMoisture) {
    final points = _telemetryHistory[sensorId];
    if (points != null && points.isNotEmpty) {
      return points.map((p) => p.moisture).toList();
    }
    return [currentMoisture];
  }

  List<TimelineEvent> getTimeline(String sensorId, double currentMoisture) {
    final List<TimelineEvent> combined = [
      ...(_wateringEvents[sensorId] ?? const []),
      ...(_alertEvents[sensorId] ?? const []),
    ];
    combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return combined;
  }

  List<TimelineEvent> getAllGardenTimeline() {
    final List<TimelineEvent> all = [];
    _wateringEvents.forEach((_, list) => all.addAll(list));
    _alertEvents.forEach((_, list) => all.addAll(list));
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  Future<void> _checkAndTriggerAutoWatering(Plant plant, SensorData sensor) async {
    final sId = plant.sensorId;
    final pumpState = getPumpState(sId);

    if (!pumpState.autoWatering) return;
    if (pumpState.requestedState || pumpState.actualState) return;
    if (!sensor.isOnlineWithThreshold(_offlineTimeoutMinutes)) return;

    if (sensor.moisture < plant.minMoisture) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastRun = _lastAutoWateringTimestamp[sId] ?? 0;
      if (now - lastRun < 30 * 60 * 1000) return;

      final dailyCount = _dailyAutoWateringCount[sId] ?? 0;
      if (dailyCount >= 3) {
        await _recordSeparatedEvent(
          sId,
          "Günlük Otomatik Sulama Limiti Doldu (${plant.name})",
          "Güvenlik amacıyla günde en fazla 3 kez otomatik sulama yapılır.",
          'alert',
        );
        return;
      }

      _lastAutoWateringTimestamp[sId] = now;
      _dailyAutoWateringCount[sId] = dailyCount + 1;

      await _recordSeparatedEvent(
        sId,
        "Otomatik Sulama Başlatıldı (${plant.name})",
        "Nem %${sensor.moisture.toInt()} < Eşik %${plant.minMoisture}. Pompa $_maxPumpSeconds sn süreyle tetiklendi.",
        'watering',
      );

      await requestPumpState(
        sensorId: sId,
        requestedState: true,
        maxDurationSeconds: _maxPumpSeconds,
        autoWatering: true,
      );
    }
  }

  Future<void> requestPumpState({
    required String sensorId,
    required bool requestedState,
    int? maxDurationSeconds,
    bool? autoWatering,
  }) async {
    if (sensorId.isEmpty) return;

    final effectiveDuration = maxDurationSeconds ?? _maxPumpSeconds;
    final prev = _pumpStates[sensorId] ?? PumpCommandState(maxDurationSeconds: effectiveDuration);
    final sensor = getSensor(sensorId);

    if (autoWatering == true && (sensor == null || !sensor.isOnlineWithThreshold(_offlineTimeoutMinutes))) {
      await _recordSeparatedEvent(
        sensorId,
        "Otomatik Sulama Güvenlik Kilidi ($sensorId)",
        "Sensör verisi güncel olmadığı için otomatik sulama reddedildi.",
        'alert',
      );
      return;
    }

    if (requestedState && sensor != null) {
      _preWateringMoisture[sensorId] = sensor.moisture;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final bool nextActualState = _isHardwareMode ? prev.actualState : requestedState;

    final updated = PumpCommandState(
      requestedState: requestedState,
      actualState: nextActualState,
      autoWatering: autoWatering ?? prev.autoWatering,
      maxDurationSeconds: effectiveDuration,
      updatedAt: now,
      timedOut: false,
    );

    _pumpStates[sensorId] = updated;

    _pumpWatchdogTimers[sensorId]?.cancel();
    if (_isHardwareMode && requestedState) {
      _pumpWatchdogTimers[sensorId] = Timer(const Duration(seconds: 20), () async {
        final currentState = _pumpStates[sensorId];
        if (currentState != null && currentState.requestedState && !currentState.actualState) {
          _pumpStates[sensorId] = PumpCommandState(
            requestedState: false,
            actualState: false,
            autoWatering: currentState.autoWatering,
            maxDurationSeconds: effectiveDuration,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            timedOut: true,
          );
          await _recordSeparatedEvent(
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
      final pre = current?.moisture ?? 30.0;
      final nextMoisture = (pre + 22.0).clamp(0.0, 95.0);
      await simulateSensorReading(
        sensorId: sensorId,
        moisture: nextMoisture,
        temperature: current?.temperature ?? 24.0,
        light: current?.light ?? 65.0,
      );
      _wateringReports[sensorId] = WateringEffectivenessReport(
        sensorId: sensorId,
        preMoisture: pre,
        postMoisture: nextMoisture,
        timestamp: now,
      );
    }

    await _recordSeparatedEvent(
      sensorId,
      requestedState ? "Pompa Komutu: AÇIK ($sensorId)" : "Pompa Komutu: KAPALI ($sensorId)",
      _isHardwareMode
          ? "ESP32 onayı bekleniyor (Maks. süre: ${effectiveDuration}sn)."
          : "Simülasyon modunda pompa çalıştırıldı (${effectiveDuration}sn).",
      'watering',
    );

    try {
      await _db.child('pumpCommands').child(sensorId).update({
        'requestedState': requestedState,
        'autoWatering': updated.autoWatering,
        'maxDurationSeconds': effectiveDuration,
        'updatedAt': now,
        'timedOut': false,
      });
    } catch (_) {}
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
      isSimulated: true,
    );

    _simulatedSensors[sensorId] = simulated;
    await _appendAndPersistHistoryPoint(
      sensorId,
      TelemetryPoint(
        timestamp: now,
        moisture: moisture,
        temperature: temperature,
        light: light,
      ),
    );

    final linkedPlant = _authorizedPlantsBySensor[sensorId];
    if (linkedPlant != null) {
      if (moisture < linkedPlant.minMoisture) {
        await _recordSeparatedEvent(
          sensorId,
          "Kritik Nem Uyarısı (${linkedPlant.name})",
          "Toprak nemi %${moisture.toInt()} seviyesine düştü (Eşik: %${linkedPlant.minMoisture}).",
          'alert',
        );
      }
      await _checkAndTriggerAutoWatering(linkedPlant, simulated);
    }
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
    _clearAllSubscriptions();
    _authSubscription?.cancel();
    _alertStreamController.close();
    super.dispose();
  }
}