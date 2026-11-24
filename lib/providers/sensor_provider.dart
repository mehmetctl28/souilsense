import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';
import '../models/plant.dart';
import '../models/pump_command.dart';
import '../services/realtime_store.dart';
export '../models/pump_command.dart';

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

  factory TimelineEvent.fromMap(
    String sensorId,
    Map<dynamic, dynamic> map, {
    String? forcedType,
  }) {
    return TimelineEvent(
      sensorId: sensorId,
      title: (map['title'] ?? '').toString(),
      subtitle: (map['subtitle'] ?? '').toString(),
      timestamp: SensorData.parseSafeInt(map['timestamp'], fallback: 0),
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
  final RealtimeStore _store;
  final int Function() _clock;
  final Duration confirmationTimeout;
  String? _uid;
  int _epoch = 0;
  bool _disposed = false, _notifying = false;
  bool _connected = false, _hasServerClock = false;
  int _serverOffset = 0;
  bool _isHardwareMode, _notificationsEnabled = true;
  int _maxPumpSeconds, _offlineTimeoutMinutes;
  int _simMaxPumpSeconds = 15, _simOfflineMinutes = 30;
  final _hardwareSensors = <String, SensorData>{};
  final _simulatedSensors = <String, SensorData>{};
  final _configs = <String, SensorConfig>{};
  final _simConfigs = <String, SensorConfig>{};
  final _commands = <String, Map>{};
  final _statuses = <String, Map>{};
  final _simPumps = <String, PumpCommandState>{};
  final _autoEnabled = <String, bool>{};
  final _errors = <String, String>{};
  final _timedOut = <String, String>{};
  final _sending = <String>{};
  final _paired = <String>{};
  final _connecting = <String>{};
  final _hardwareHistory = <String, List<TelemetryPoint>>{};
  final _simHistory = <String, List<TelemetryPoint>>{};
  final _hardwareEvents = <String, List<TimelineEvent>>{};
  final _simEvents = <String, List<TimelineEvent>>{};
  final _reports = <String, WateringEffectivenessReport>{};
  final _simReports = <String, WateringEffectivenessReport>{};
  final _preWatering = <String, double>{};
  final _completedAt = <String, int>{};
  final _watchdogs = <String, Timer>{};
  final _simTimers = <String, Timer>{};
  final _subscriptions = <String, List<StreamSubscription<Object?>>>{};
  final _globalSubs = <StreamSubscription<Object?>>[];
  Map<String, Plant> _plants = {};
  final _alerts = StreamController<TimelineEvent>.broadcast();

  SensorProvider({
    RealtimeStore? store,
    int Function()? clock,
    bool initialHardwareMode = false,
    int initialMaxPumpSeconds = 15,
    int initialOfflineMinutes = 30,
    this.confirmationTimeout = const Duration(seconds: 20),
  })  : _store = store ?? FirebaseRealtimeStore(),
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
        _isHardwareMode = initialHardwareMode,
        _maxPumpSeconds = initialMaxPumpSeconds.clamp(1, PumpPolicy.maxSeconds),
        _offlineTimeoutMinutes = initialOfflineMinutes.clamp(1, 30) {
    _uid = _store.uid;
    _globalSubs.add(_store.authChanges.listen((uid) {
      if (uid == _uid) return;
      _uid = uid;
      _clearSession();
      _notify();
    }));
    _globalSubs.add(_store.watch('.info/connected').listen((v) {
      _connected = v == true;
      _notify();
    }));
    _globalSubs.add(_store.watch('.info/serverTimeOffset').listen((v) {
      _hasServerClock = v is num && v.isFinite;
      _serverOffset = _hasServerClock ? (v as num).toInt() : 0;
    }));
    unawaited(reloadSafetySettings());
  }

  int get _now => _clock() + _serverOffset;
  bool get isHardwareMode => _isHardwareMode;
  bool get notificationsEnabled => _notificationsEnabled;
  int get maxPumpSeconds =>
      _isHardwareMode ? _maxPumpSeconds : _simMaxPumpSeconds;
  int get offlineTimeoutMinutes =>
      _isHardwareMode ? _offlineTimeoutMinutes : _simOfflineMinutes;
  bool isSensorPaired(String id) => _paired.contains(id);
  static bool validSensorId(String id) =>
      RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id);
  Stream<TimelineEvent> get alertStream => _alerts.stream;
  Map<String, String> get sensorAccessErrors => Map.unmodifiable(_errors);
  Map<String, SensorData> get sensors =>
      Map.unmodifiable(_isHardwareMode ? _hardwareSensors : _simulatedSensors);
  int get connectedHardwareSensorCount => _hardwareSensors.values
      .where((s) => s.isOnlineWithThreshold(_offlineTimeoutMinutes))
      .length;
  int? get lastHardwareUpdateTimestamp {
    final times =
        _hardwareSensors.values.map((s) => s.lastUpdate).where((t) => t > 0);
    return times.isEmpty ? null : times.reduce((a, b) => a > b ? a : b);
  }

  void _notify() {
    if (_disposed || _notifying) return;
    _notifying = true;
    scheduleMicrotask(() {
      _notifying = false;
      if (!_disposed) notifyListeners();
    });
  }

  bool _current(int epoch, String? uid) =>
      !_disposed &&
      epoch == _epoch &&
      uid != null &&
      uid == _uid &&
      uid == _store.uid;
  bool _live(int epoch, String? uid) => _current(epoch, uid) && _isHardwareMode;

  void _stopSubscriptions() {
    _epoch++;
    for (final list in _subscriptions.values) {
      for (final sub in list) {
        sub.cancel();
      }
    }
    _subscriptions.clear();
    for (final t in _watchdogs.values) {
      t.cancel();
    }
    _watchdogs.clear();
    _connecting.clear();
    _paired.clear();
    _sending.clear();
    _errors.clear();
    _commands.clear();
    _statuses.clear();
    _hardwareSensors.clear();
    _configs.clear();
    _autoEnabled.clear();
    _timedOut.clear();
    _preWatering.clear();
    _completedAt.clear();
    _reports.clear();
    _hardwareHistory.clear();
    _hardwareEvents.clear();
  }

  void _clearSession() {
    _stopSubscriptions();
    for (final t in _simTimers.values) {
      t.cancel();
    }
    _simTimers.clear();
    _simulatedSensors.clear();
    _simPumps.clear();
    _simConfigs.clear();
    _simHistory.clear();
    _simEvents.clear();
    _simReports.clear();
    _plants.clear();
  }

  void syncAuthorizedPlants(List<Plant> plants) {
    _plants = {
      for (final p in plants)
        if (p.userId == _uid && validSensorId(p.sensorId.trim()))
          p.sensorId.trim(): p
    };
    for (final id in _subscriptions.keys.toList()) {
      if (!_plants.containsKey(id)) {
        for (final sub in _subscriptions.remove(id)!) {
          sub.cancel();
        }
        _watchdogs.remove(id)?.cancel();
        _paired.remove(id);
        _hardwareSensors.remove(id);
        _commands.remove(id);
        _statuses.remove(id);
        _errors.remove(id);
      }
    }
    if (!_isHardwareMode) {
      for (final plant in _plants.values) {
        ensureSensorExists(plant.sensorId,
            initialMoisture: plant.moistureLevel);
      }
      return;
    }
    if (_uid == null) return;
    for (final id in _plants.keys) {
      if (!_subscriptions.containsKey(id) &&
          !_connecting.contains(id) &&
          !_errors.containsKey(id)) {
        _subscribe(id);
      }
    }
  }

  Future<void> _subscribe(String id) async {
    final epoch = _epoch, uid = _uid;
    if (_connecting.contains(id) ||
        _subscriptions.containsKey(id) ||
        !_live(epoch, uid)) {
      return;
    }
    _connecting.add(id);
    try {
      final owner = await _store.read('sensorOwners/$id');
      if (!_live(epoch, uid) || !_plants.containsKey(id)) return;
      final ownerUid = owner is Map ? owner['uid'] : owner;
      if (ownerUid != uid) {
        _errors[id] = 'Cihaz eşleştirilmedi. Cihazın eşleştirme kodunu girin.';
        return;
      }
      _paired.add(id);
      final subs = <StreamSubscription<Object?>>[];
      _subscriptions[id] = subs;
      void listen(String path, void Function(Object?) receive) {
        subs.add(_store.watch(path).listen((v) {
          if (_live(epoch, uid) && _plants.containsKey(id)) {
            receive(v);
            _notify();
          }
        }, onError: (Object _) {
          if (_live(epoch, uid)) {
            _errors[id] =
                'Cihaz verisine erişilemedi. Bağlantıyı ve yetkiyi kontrol edin.';
            _notify();
          }
        }));
      }

      listen('sensorConfigs/$id', (v) {
        if (v is Map) {
          _configs[id] = SensorConfig.fromMap(id, v);
          _autoEnabled[id] = v['autoWatering'] == true;
        }
      });
      listen('pumpCommands/$id', (v) {
        _commands[id] = v is Map ? v : {};
        _onPumpChanged(id);
      });
      listen('pumpStatus/$id', (v) {
        _statuses[id] = v is Map ? v : {};
        _onPumpChanged(id);
      });
      listen('sensors/$id/current', (v) {
        if (v is Map) _onSensor(id, v);
      });
      listen('users/$uid/sensorHistory/$id', (v) {
        if (v is! Map) return;
        final points = <TelemetryPoint>[];
        v.forEach((key, data) {
          final ts = SensorData.normalizeTimestamp(key);
          if (data is Map && ts > 0) {
            points.add(TelemetryPoint.fromMap(ts, data));
          }
        });
        points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _hardwareHistory[id] =
            points.length > 100 ? points.sublist(points.length - 100) : points;
      });
      for (final kind in ['wateringEvents', 'alerts']) {
        listen('users/$uid/$kind/$id', (v) {
          if (v is! Map) return;
          final type = kind == 'alerts' ? 'alert' : 'watering';
          final rest =
              (_hardwareEvents[id] ?? []).where((e) => e.type != type).toList();
          rest.addAll(v.values
              .whereType<Map>()
              .map((m) => TimelineEvent.fromMap(id, m, forcedType: type)));
          rest.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _hardwareEvents[id] = rest;
        });
      }
    } catch (_) {
      if (_live(epoch, uid)) {
        _errors[id] =
            'Cihaz eşleştirmesi doğrulanamadı. Kodu ve erişimi kontrol edin.';
      }
    } finally {
      if (epoch == _epoch) {
        _connecting.remove(id);
        _notify();
      }
    }
  }

  Future<bool> pairSensor(String id, String code) async {
    final epoch = _epoch, uid = _uid;
    if (!_live(epoch, uid) ||
        !_plants.containsKey(id) ||
        code.trim().length < 16) {
      return false;
    }
    try {
      // A write-once rules check compares the proof with an unreadable,
      // administrator-provisioned secret. Competing claims cannot both commit.
      await _store
          .set('sensorOwners/$id', {'uid': uid, 'claimCode': code.trim()});
      if (!_live(epoch, uid)) return false;
      _errors.remove(id);
      await _subscribe(id);
      return _paired.contains(id);
    } catch (_) {
      if (_live(epoch, uid)) {
        _errors[id] =
            'Eşleştirme başarısız: kod yanlış, süresi dolmuş veya cihaz eşleştirilmiş.';
        _notify();
      }
      return false;
    }
  }

  Future<void> retrySensor(String id) async {
    if (!_isHardwareMode) return;
    _errors.remove(id);
    if (!_subscriptions.containsKey(id)) await _subscribe(id);
  }

  void _onPumpChanged(String id) {
    final state = getPumpState(id);
    if (state.acknowledged) {
      _watchdogs.remove(id)?.cancel();
      _timedOut.remove(id);
      if (state.completed) {
        _completedAt[id] =
            SensorData.normalizeTimestamp(_statuses[id]?['updatedAt']);
      }
    }
  }

  void _onSensor(String id, Map data) {
    final sensor = SensorData.fromMap(id, data, config: _configs[id]);
    _hardwareSensors[id] = sensor;
    if (!sensor.isOnlineWithThreshold(_offlineTimeoutMinutes) ||
        sensor.isSimulated) {
      return;
    }
    final completed = _completedAt[id];
    if (completed != null &&
        sensor.lastUpdate >= completed + 10000 &&
        _preWatering.containsKey(id)) {
      _reports[id] = WateringEffectivenessReport(
          sensorId: id,
          preMoisture: _preWatering.remove(id)!,
          postMoisture: sensor.moisture,
          timestamp: sensor.lastUpdate);
      _completedAt.remove(id);
    }
    final history = _hardwareHistory.putIfAbsent(id, () => []);
    if (history.isEmpty ||
        sensor.lastUpdate > history.last.timestamp &&
            ((sensor.moisture - history.last.moisture).abs() >= 1 ||
                sensor.lastUpdate - history.last.timestamp >= 300000)) {
      final point = TelemetryPoint(
          timestamp: sensor.lastUpdate,
          moisture: sensor.moisture,
          temperature: sensor.temperature,
          light: sensor.light);
      history.add(point);
      if (history.length > 100) history.removeAt(0);
      final epoch = _epoch, uid = _uid;
      if (_live(epoch, uid)) {
        _store
            .set('users/$uid/sensorHistory/$id/${point.timestamp}',
                point.toMap())
            .catchError((Object _) {});
      }
    }
    final plant = _plants[id];
    if (plant != null &&
        _autoEnabled[id] == true &&
        sensor.moisture < plant.minMoisture) {
      requestPumpState(sensorId: id, requestedState: true, automatic: true);
    }
  }

  Future<bool> setHardwareMode(bool enabled) async {
    if (enabled == _isHardwareMode) return true;
    if (_sending.isNotEmpty ||
        (_isHardwareMode &&
            _commands.keys.any((id) {
              final cmd = _commands[id]!;
              final expiry =
                  SensorData.parseSafeInt(cmd['expiresAt'], fallback: 0);
              final seconds = SensorData.parseSafeInt(cmd['maxDurationSeconds'],
                  fallback: 30);
              return getPumpState(id).actualState ||
                  (cmd['requestedState'] == true &&
                      !getPumpState(id).completed &&
                      _now < expiry + seconds * 1000);
            }))) {
      return false;
    }
    _stopSubscriptions();
    _isHardwareMode = enabled;
    if (enabled) syncAuthorizedPlants(_plants.values.toList());
    _notify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_hardware_mode', enabled);
    return true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    _notify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }

  Future<void> triggerTestNotification() async {
    _alerts.add(TimelineEvent(
        sensorId: 'sistem',
        title: 'Uygulama içi bildirim testi',
        subtitle: 'Yerel uyarı gösterimi.',
        timestamp: _now,
        type: 'alert'));
  }

  Future<void> reloadSafetySettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    _notify();
  }

  void _recordHardwareAlert(
      String id, String key, String title, String message) {
    if (!_live(_epoch, _uid) || !_plants.containsKey(id)) return;
    final event = TimelineEvent(
        sensorId: id,
        title: title,
        subtitle: message,
        timestamp: _now,
        type: 'alert');
    if (_notificationsEnabled) _alerts.add(event);
    unawaited(_store
        .set('users/$_uid/alerts/$id/$key', event.toMap())
        .catchError((Object _) {}));
  }

  Future<void> updateSafetySettings(
      {required int maxPumpSeconds, required int offlineTimeoutMinutes}) async {
    if (!_isHardwareMode) {
      _simMaxPumpSeconds = maxPumpSeconds.clamp(1, PumpPolicy.maxSeconds);
      _simOfflineMinutes = offlineTimeoutMinutes.clamp(1, 30);
      _notify();
      return;
    }
    final epoch = _epoch, uid = _uid;
    _maxPumpSeconds = maxPumpSeconds.clamp(1, PumpPolicy.maxSeconds);
    _offlineTimeoutMinutes = offlineTimeoutMinutes.clamp(1, 30);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_pump_seconds', _maxPumpSeconds);
    await prefs.setInt('offline_timeout_minutes', _offlineTimeoutMinutes);
    _notify();
    if (_live(epoch, uid)) {
      for (final id in _paired.toList()) {
        await saveSensorConfig(SensorConfig(
            sensorId: id,
            dryAdcValue: getSensorConfig(id).dryAdcValue,
            wetAdcValue: getSensorConfig(id).wetAdcValue,
            readIntervalSeconds: getSensorConfig(id).readIntervalSeconds,
            maxPumpSeconds: _maxPumpSeconds));
      }
    }
  }

  SensorConfig getSensorConfig(String id) =>
      (_isHardwareMode ? _configs : _simConfigs)[id] ??
      SensorConfig(sensorId: id, maxPumpSeconds: maxPumpSeconds);
  Future<bool> saveSensorConfig(SensorConfig config) async {
    if (!config.isValid) return false;
    if (!_isHardwareMode) {
      _simConfigs[config.sensorId] = config;
      _notify();
      return true;
    }
    final epoch = _epoch, uid = _uid, id = config.sensorId;
    if (!_live(epoch, uid) || !_paired.contains(id) || !_connected) {
      return false;
    }
    try {
      await _store.update('sensorConfigs/$id', config.toMap());
      if (!_live(epoch, uid)) return false;
      _configs[id] = config;
      _notify();
      return true;
    } catch (_) {
      _errors[id] = 'Cihaz ayarları kaydedilemedi.';
      _notify();
      return false;
    }
  }

  Future<bool> setAutoWatering(String id, bool enabled) async {
    if (!_isHardwareMode) {
      final prev = getPumpState(id);
      _simPumps[id] = PumpCommandState(
          autoWatering: enabled,
          actualState: prev.actualState,
          actualStateKnown: true,
          requestedState: prev.requestedState);
      _notify();
      return true;
    }
    final epoch = _epoch, uid = _uid;
    if (!_live(epoch, uid) || !_paired.contains(id) || !_connected) {
      return false;
    }
    try {
      await _store.update('sensorConfigs/$id', {
        'autoWatering': enabled,
        if (_plants[id] != null) 'minMoisture': _plants[id]!.minMoisture,
        if (_plants[id] != null) 'maxMoisture': _plants[id]!.maxMoisture,
      });
      if (!_live(epoch, uid)) return false;
      _autoEnabled[id] = enabled;
      _notify();
      return true;
    } catch (_) {
      _errors[id] = 'Otomatik sulama ayarı kaydedilemedi.';
      _notify();
      return false;
    }
  }

  PumpCommandState getPumpState(String id, {bool fallbackPumpOn = false}) {
    if (!_isHardwareMode) {
      return _simPumps[id] ?? const PumpCommandState(actualStateKnown: true);
    }
    final cmd = _commands[id] ?? {};
    final expires = SensorData.parseSafeInt(cmd['expiresAt'], fallback: 0);
    final status = _statuses[id] ?? {};
    final expired = cmd['commandId'] != null &&
        expires > 0 &&
        _now >= expires &&
        (status['commandId'] != cmd['commandId'] ||
            status['protocolVersion'] != 2);
    return PumpCommandState.fromRecords(cmd, status,
        autoWatering: _autoEnabled[id] ?? false,
        sending: _sending.contains(id),
        timedOut: expired ||
            (cmd['commandId'] != null && _timedOut[id] == cmd['commandId']),
        error: _errors[id],
        now: _now);
  }

  Future<bool> requestPumpState(
      {required String sensorId,
      required bool requestedState,
      int? maxDurationSeconds,
      bool automatic = false}) async {
    final id = sensorId, epoch = _epoch, uid = _uid;
    final deviceLimit = getSensorConfig(id).maxPumpSeconds;
    // A stop has no run duration. Never let an outdated phone setting prevent it.
    final seconds = requestedState
        ? maxDurationSeconds ??
            (deviceLimit < maxPumpSeconds ? deviceLimit : maxPumpSeconds)
        : 1;
    if (id.isEmpty ||
        !_plants.containsKey(id) ||
        _sending.contains(id) ||
        seconds < 1 ||
        seconds > PumpPolicy.maxSeconds) {
      return false;
    }
    if (!_isHardwareMode) {
      if (requestedState && getPumpState(id).actualState) return false;
      final now = _now;
      _simTimers.remove(id)?.cancel();
      _simPumps[id] = PumpCommandState(
          requestedState: requestedState,
          actualState: requestedState,
          actualStateKnown: true,
          autoWatering: getPumpState(id).autoWatering,
          maxDurationSeconds: seconds,
          updatedAt: now);
      if (requestedState) {
        final pre = getSensor(id)?.moisture ?? 30;
        await simulateSensorReading(
            sensorId: id, moisture: (pre + 22).clamp(0, 100));
        _simReports[id] = WateringEffectivenessReport(
            sensorId: id,
            preMoisture: pre,
            postMoisture: getSensor(id)!.moisture,
            timestamp: now);
        _simTimers[id] = Timer(Duration(seconds: seconds), () {
          _simPumps[id] = PumpCommandState(
              actualStateKnown: true,
              autoWatering: _simPumps[id]?.autoWatering ?? false);
          _notify();
        });
      }
      _localEvent(id, '[Simülasyon] Pompa komutu',
          requestedState ? 'Sanal pompa açık' : 'Sanal pompa kapalı');
      _notify();
      return true;
    }
    _errors.remove(id);
    final sensor = _hardwareSensors[id];
    final state = getPumpState(id);
    if (!_live(epoch, uid) ||
        !_paired.contains(id) ||
        !_connected ||
        !_hasServerClock) {
      _errors[id] =
          'Cihaza bağlı değil. Bağlantıyı ve eşleştirmeyi kontrol edin.';
      _notify();
      return false;
    }
    if (requestedState &&
        (sensor == null ||
            sensor.protocolVersion != 2 ||
            sensor.isSimulated ||
            !sensor.isOnlineWithThreshold(_offlineTimeoutMinutes))) {
      _errors[id] =
          'Güncel ve geçerli cihaz ölçümü gerekli; cihaz uyumunu kontrol edin.';
      _notify();
      return false;
    }
    if (requestedState && (state.isBusy || !state.actualStateKnown)) {
      return false;
    }
    _sending.add(id);
    _notify();
    final commandId = _store.newKey();
    final issuedAt = _now;
    Map<String, Object?>? submitted;
    try {
      final ok = await _store.transaction('pumpCommands/$id', (current) {
        if (!_live(epoch, uid) ||
            !_plants.containsKey(id) ||
            !_paired.contains(id) ||
            !_connected ||
            _now >= issuedAt + PumpPolicy.ttlMs) return null;
        final old = current is Map ? current : {};
        final expires = SensorData.parseSafeInt(old['expiresAt'], fallback: 0);
        final duration =
            SensorData.parseSafeInt(old['maxDurationSeconds'], fallback: 30);
        final status = _statuses[id] ?? {};
        final finished = status['commandId'] == old['commandId'] &&
            (status['state'] == 'completed' || status['state'] == 'rejected') &&
            status['actualState'] == false;
        if (requestedState &&
            old['requestedState'] == true &&
            !finished &&
            _now < expires + duration * 1000) {
          return null;
        }
        submitted = PumpPolicy.next(
            previous: current,
            commandId: commandId,
            now: issuedAt,
            requestedState: requestedState,
            automatic: automatic,
            seconds: seconds);
        return submitted;
      }).timeout(const Duration(seconds: 20));
      if (!_live(epoch, uid)) return false;
      if (!ok || submitted == null) {
        _errors[id] =
            'Komut gönderilmedi: bekleyen işlem, süre veya günlük limit kontrolü.';
        return false;
      }
      _commands[id] = submitted!;
      _timedOut.remove(id);
      if (requestedState && sensor != null) _preWatering[id] = sensor.moisture;
      _watchdogs.remove(id)?.cancel();
      if (!getPumpState(id).acknowledged) {
        _watchdogs[id] = Timer(confirmationTimeout, () {
          if (_live(epoch, uid) &&
              _commands[id]?['commandId'] == commandId &&
              !getPumpState(id).acknowledged) {
            _timedOut[id] = commandId;
            // Expiry is enforced by rules and firmware. Never claim the relay
            // is OFF merely because the app did not receive an acknowledgement.
            _recordHardwareAlert(
                id,
                'timeout_$commandId',
                'Pompa komutu onaylanmadı',
                'Cihazın gerçek durumu bilinmiyor.');
            _notify();
          }
        });
      }
      unawaited(_store.set('users/$uid/wateringEvents/$id/$commandId', {
        'title': requestedState
            ? 'Sulama komutu gönderildi'
            : 'Durdurma komutu gönderildi',
        'subtitle': 'Cihaz onayı bekleniyor.',
        'timestamp': _now,
        'type': 'watering',
      }).catchError((Object _) {}));
      return true;
    } catch (_) {
      if (_live(epoch, uid)) {
        _errors[id] = 'Komut kaydedilemedi; cihaz onayı alınmadı.';
      }
      return false;
    } finally {
      if (epoch == _epoch) {
        _sending.remove(id);
        _notify();
      }
    }
  }

  SensorData? getSensor(String id) =>
      (_isHardwareMode ? _hardwareSensors : _simulatedSensors)[id];
  bool isSensorOnline(String id) =>
      getSensor(id)?.isOnlineWithThreshold(_offlineTimeoutMinutes) ?? false;
  WateringEffectivenessReport? getWateringReport(String id) =>
      (_isHardwareMode ? _reports : _simReports)[id];
  List<TelemetryPoint> getTelemetryHistory(String id) => List.unmodifiable(
      (_isHardwareMode ? _hardwareHistory : _simHistory)[id] ?? []);
  List<double> getMoistureHistory(String id, double currentMoisture) =>
      getTelemetryHistory(id).map((p) => p.moisture).toList();
  List<TimelineEvent> getTimeline(String id, double currentMoisture) =>
      List.unmodifiable(
          (_isHardwareMode ? _hardwareEvents : _simEvents)[id] ?? []);

  List<TimelineEvent> getAllGardenTimeline() {
    final events = (_isHardwareMode ? _hardwareEvents : _simEvents)
        .values
        .expand((list) => list)
        .toList();
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }

  void _localEvent(String id, String title, String subtitle) {
    final list = _simEvents.putIfAbsent(id, () => []);
    list.insert(
        0,
        TimelineEvent(
            sensorId: id,
            title: title,
            subtitle: subtitle,
            timestamp: _now,
            type: 'watering'));
    if (list.length > 100) list.removeLast();
  }

  Future<void> simulateSensorReading(
      {required String sensorId,
      double? moisture,
      double? temperature,
      double? light,
      int? rawAdc}) async {
    if (_isHardwareMode || !_plants.containsKey(sensorId)) return;
    final prev = _simulatedSensors[sensorId];
    final sensor = SensorData.fromMap(
        sensorId,
        {
          'moisture': moisture ?? prev?.moisture ?? 45,
          'temperature': temperature ?? prev?.temperature ?? 24,
          'light': light ?? prev?.light ?? 60,
          if (rawAdc != null) 'rawAdc': rawAdc,
          'lastUpdate': _now,
        },
        config: getSensorConfig(sensorId),
        isSimulated: true);
    _simulatedSensors[sensorId] = sensor;
    if (sensor.isValidMeasurement) {
      final history = _simHistory.putIfAbsent(sensorId, () => []);
      history.add(TelemetryPoint(
          timestamp: _now,
          moisture: sensor.moisture,
          temperature: sensor.temperature,
          light: sensor.light));
      if (history.length > 100) history.removeAt(0);
    }
    _notify();
  }

  Future<void> ensureSensorExists(String id,
      {double initialMoisture = 45}) async {
    if (!_isHardwareMode && !_simulatedSensors.containsKey(id)) {
      await simulateSensorReading(sensorId: id, moisture: initialMoisture);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _clearSession();
    for (final sub in _globalSubs) {
      sub.cancel();
    }
    _alerts.close();
    super.dispose();
  }
}
