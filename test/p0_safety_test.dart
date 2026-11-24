import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:demo_app/models/plant.dart';
import 'package:demo_app/models/sensor_data.dart';
import 'package:demo_app/providers/sensor_provider.dart';
import 'package:demo_app/providers/todo_provider.dart';
import 'support/fake_store.dart';

int now() => DateTime.now().millisecondsSinceEpoch;
Map<String, Object?> packet({double moisture = 40}) => {
      'protocolVersion': 2,
      'moisture': moisture,
      'temperature': 24,
      'light': 60,
      'lastUpdate': now(),
    };
Plant plant() => Plant(
    id: 'p1',
    userId: 'user-a',
    name: 'Test bitkisi',
    type: 'Orkide',
    sensorId: 's1',
    moistureLevel: 40,
    minMoisture: 30);
FakeStore readyStore() {
  final store = FakeStore();
  store.seed('.info/connected', true);
  store.seed('.info/serverTimeOffset', 0);
  store.seed('sensorOwners/s1', {'uid': 'user-a'});
  store.seed('sensorConfigs/s1',
      {'maxPumpSeconds': 15, 'minMoisture': 30, 'autoWatering': false});
  store.seed('sensors/s1/current', packet());
  store.seed('pumpStatus/s1', {
    'protocolVersion': 2,
    'commandId': '',
    'actualState': false,
    'state': 'idle',
    'updatedAt': now()
  });
  return store;
}

Future<SensorProvider> hardware(FakeStore store,
    {Duration timeout = const Duration(seconds: 20)}) async {
  final p = SensorProvider(
      store: store, initialHardwareMode: true, confirmationTimeout: timeout);
  p.syncAuthorizedPlants([plant()]);
  await settle();
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('device duration is respected and cannot prevent an explicit stop',
      () async {
    final store = readyStore();
    store.seed('sensorConfigs/s1', {'maxPumpSeconds': 3});
    final p = await hardware(store);
    expect(
        await p.requestPumpState(sensorId: 's1', requestedState: true), isTrue);
    expect((store.value('pumpCommands/s1') as Map)['maxDurationSeconds'], 3);
    // A second phone can lower the device limit while a command is pending.
    store.seed('sensorConfigs/s1', {'maxPumpSeconds': 1});
    await settle();
    expect(await p.requestPumpState(sensorId: 's1', requestedState: false),
        isTrue);
    final stop = store.value('pumpCommands/s1') as Map;
    expect(stop['requestedState'], isFalse);
    expect(stop['maxDurationSeconds'], 1);
    p.dispose();
    await store.close();
  });
  test('removed plant cancels a request still waiting for its transaction',
      () async {
    final store = readyStore();
    final p = await hardware(store);
    store.transactionGate = Completer<void>();
    final request = p.requestPumpState(sensorId: 's1', requestedState: true);
    p.syncAuthorizedPlants([]);
    store.transactionGate!.complete();
    expect(await request, isFalse);
    expect(store.writes.where((path) => path == 'pumpCommands/s1'), isEmpty);
    p.dispose();
    await store.close();
  });
  test(
      'stored notification preference is restored and timeout stays in history',
      () async {
    SharedPreferences.setMockInitialValues({'notifications_enabled': false});
    final store = readyStore();
    final p = await hardware(store, timeout: const Duration(milliseconds: 5));
    final alerts = <TimelineEvent>[];
    final subscription = p.alertStream.listen(alerts.add);
    expect(p.notificationsEnabled, isFalse);
    await p.requestPumpState(sensorId: 's1', requestedState: true);
    await settle();
    expect(alerts, isEmpty);
    expect(
        store.writes.where((path) => path.startsWith('users/user-a/alerts/')),
        hasLength(1));
    await subscription.cancel();
    p.dispose();
    await store.close();
  });
  test('a delayed transaction must not refresh an expired user command',
      () async {
    final store = readyStore();
    var time = now();
    final p = SensorProvider(
        store: store, clock: () => time, initialHardwareMode: true);
    p.syncAuthorizedPlants([plant()]);
    await settle();
    store.transactionGate = Completer<void>();
    final request = p.requestPumpState(sensorId: 's1', requestedState: true);
    time += PumpPolicy.ttlMs + 1;
    store.transactionGate!.complete();
    expect(await request, isFalse);
    expect(store.writes.where((path) => path == 'pumpCommands/s1'), isEmpty);
    p.dispose();
    await store.close();
  });
  test('simulation safety settings never carry into hardware settings',
      () async {
    final store = readyStore();
    final p = SensorProvider(store: store, initialMaxPumpSeconds: 15);
    p.syncAuthorizedPlants([plant()]);
    await p.updateSafetySettings(maxPumpSeconds: 30, offlineTimeoutMinutes: 1);
    expect(p.maxPumpSeconds, 30);
    expect(p.offlineTimeoutMinutes, 1);
    expect(await p.setHardwareMode(true), isTrue);
    await settle();
    expect(p.maxPumpSeconds, 15);
    expect(p.offlineTimeoutMinutes, 30);
    expect(store.writes.where((path) => path.startsWith('sensorConfigs')),
        isEmpty);
    p.dispose();
    await store.close();
  });
  group('measurement validation', () {
    test(
        'never turns uptime, missing, malformed or nonfinite timestamps into now',
        () {
      for (final value in [
        null,
        0,
        -1,
        60000,
        1546300800,
        'oops',
        'NaN',
        double.infinity,
        1.5
      ]) {
        expect(SensorData.normalizeTimestamp(value), 0, reason: '$value');
      }
      expect(SensorData.normalizeTimestamp(1700000000), 1700000000000);
      expect(SensorData.normalizeTimestamp(1700000000000), 1700000000000);
    });
    test('missing or invalid fields cannot be a live watering measurement', () {
      for (final bad in [
        {...packet(), 'moisture': null},
        {...packet(), 'moisture': 'not-a-number'},
        {...packet(), 'moisture': -1},
        {...packet(), 'temperature': double.nan},
        {...packet(), 'light': 101},
        {...packet(), 'rawAdc': 9000},
        {...packet(), 'rawAdc': 2.5},
        {...packet(), 'lastUpdate': now() + 60000},
      ]) {
        expect(SensorData.fromMap('s1', bad).isOnline, isFalse, reason: '$bad');
      }
    });
    test(
        'ADC conversion supports both sensor directions and rejects equal endpoints',
        () {
      const normal =
          SensorConfig(sensorId: 's1', dryAdcValue: 3200, wetAdcValue: 1400);
      const reverse =
          SensorConfig(sensorId: 's1', dryAdcValue: 1400, wetAdcValue: 3200);
      expect(normal.convertAdcToMoisture(2300), 50);
      expect(reverse.convertAdcToMoisture(3200), 100);
      expect(reverse.convertAdcToMoisture(1400), 0);
      expect(
          const SensorConfig(
                  sensorId: 's1', dryAdcValue: 1000, wetAdcValue: 1000)
              .isValid,
          isFalse);
    });
  });
  test(
      'simulation pump, calibration, automatic tasks and archive make zero cloud writes',
      () async {
    final store = readyStore();
    final p = SensorProvider(store: store);
    final todos = TodoProvider(store: store);
    p.syncAuthorizedPlants([plant()]);
    await settle();
    await p.simulateSensorReading(sensorId: 's1', moisture: 5);
    todos.onTelemetryOrPlantsUpdated([plant()], p.sensors);
    expect(todos.activeTodos.length, 1);
    await p.saveSensorConfig(const SensorConfig(
        sensorId: 's1', dryAdcValue: 3000, wetAdcValue: 1000));
    await p.setAutoWatering('s1', true);
    expect(
        await p.requestPumpState(sensorId: 's1', requestedState: true), isTrue);
    await p.simulateSensorReading(sensorId: 's1', moisture: 80);
    todos.onTelemetryOrPlantsUpdated([plant()], p.sensors);
    expect(todos.completedAutoTodos.length, 1);
    expect(await p.pairSensor('s1', 'unused-proof-long-enough'), isFalse);
    await todos.addTodo('Yerel test görevi');
    await todos.toggleTodo(todos.activeTodos.first.id, false);
    await settle();
    expect(store.writes, isEmpty);
    p.dispose();
    todos.dispose();
    await store.close();
  });
  test(
      'mode switch never copies simulated pump, telemetry or calibration into hardware',
      () async {
    final store = readyStore();
    final p = SensorProvider(store: store);
    p.syncAuthorizedPlants([plant()]);
    await p.simulateSensorReading(sensorId: 's1', moisture: 5);
    await p.saveSensorConfig(const SensorConfig(
        sensorId: 's1', dryAdcValue: 3500, wetAdcValue: 500));
    await p.requestPumpState(sensorId: 's1', requestedState: true);
    await p.requestPumpState(sensorId: 's1', requestedState: false);
    expect(await p.setHardwareMode(true), isTrue);
    await settle();
    expect(p.getSensor('s1')!.isSimulated, isFalse);
    expect(p.getSensor('s1')!.moisture, 40);
    expect(p.getPumpState('s1').actualState, isFalse);
    expect(p.getSensorConfig('s1').dryAdcValue, 3200);
    expect(
        store.writes.where((s) =>
            s.startsWith('pumpCommands') ||
            s.startsWith('sensorConfigs') ||
            s.startsWith('sensorOwners')),
        isEmpty);
    p.dispose();
    await store.close();
  });
  test('command success waits for matching device acknowledgement', () async {
    final store = readyStore();
    final p = await hardware(store);
    expect(
        await p.requestPumpState(sensorId: 's1', requestedState: true), isTrue);
    final id = (store.value('pumpCommands/s1') as Map)['commandId'];
    expect(p.getPumpState('s1').isPendingConfirmation, isTrue);
    expect(p.getPumpState('s1').actualState, isFalse);
    store.seed('pumpStatus/s1', {
      'protocolVersion': 2,
      'commandId': 'older-command',
      'actualState': false,
      'state': 'completed',
      'updatedAt': now()
    });
    await settle();
    expect(p.getPumpState('s1').isPendingConfirmation, isTrue);
    store.seed('pumpStatus/s1', {
      'protocolVersion': 2,
      'commandId': id,
      'actualState': true,
      'state': 'running',
      'updatedAt': now()
    });
    await settle();
    expect(p.getPumpState('s1').actualState, isTrue);
    expect(p.getPumpState('s1').isPendingConfirmation, isFalse);
    expect(await p.setHardwareMode(false), isFalse);
    store.seed('pumpStatus/s1', {
      'protocolVersion': 2,
      'commandId': id,
      'actualState': false,
      'state': 'completed',
      'updatedAt': now()
    });
    await settle();
    expect(p.getPumpState('s1').completed, isTrue);
    expect(await p.setHardwareMode(false), isTrue);
    p.dispose();
    await store.close();
  });
  test('duplicate clicks share one in-flight command', () async {
    final store = readyStore();
    final p = await hardware(store);
    store.transactionGate = Completer<void>();
    final first = p.requestPumpState(sensorId: 's1', requestedState: true);
    expect(await p.requestPumpState(sensorId: 's1', requestedState: true),
        isFalse);
    store.transactionGate!.complete();
    expect(await first, isTrue);
    expect(store.writes.where((s) => s == 'pumpCommands/s1').length, 1);
    p.dispose();
    await store.close();
  });
  test('sign-out during a pending request cannot write a command', () async {
    final store = readyStore();
    final p = await hardware(store);
    store.transactionGate = Completer<void>();
    final request = p.requestPumpState(sensorId: 's1', requestedState: true);
    store.login(null);
    await settle();
    store.transactionGate!.complete();
    expect(await request, isFalse);
    expect(store.writes.where((s) => s == 'pumpCommands/s1'), isEmpty);
    p.dispose();
    await store.close();
  });
  test('failed command and timeout never report completed watering', () async {
    final store = readyStore();
    final p = await hardware(store, timeout: const Duration(milliseconds: 5));
    store.failWrites = true;
    expect(await p.requestPumpState(sensorId: 's1', requestedState: true),
        isFalse);
    expect(p.getPumpState('s1').completed, isFalse);
    expect(p.getPumpState('s1').error, isNotNull);
    store.failWrites = false;
    expect(
        await p.requestPumpState(sensorId: 's1', requestedState: true), isTrue);
    await settle();
    expect(p.getPumpState('s1').timedOut, isTrue);
    expect(p.getPumpState('s1').label, contains('bilinmiyor'));
    expect(p.getPumpState('s1').completed, isFalse);
    p.dispose();
    await store.close();
  });
  test('invalid measurements and old firmware cannot issue a start', () async {
    final store = readyStore();
    final p = await hardware(store);
    for (final data in [
      {...packet(), 'moisture': null},
      {...packet(), 'lastUpdate': 60000},
      {...packet(), 'protocolVersion': 1}
    ]) {
      store.seed('sensors/s1/current', data);
      await settle();
      expect(
          await p.requestPumpState(
              sensorId: 's1', requestedState: true, automatic: true),
          isFalse);
    }
    expect(store.writes.where((s) => s == 'pumpCommands/s1'), isEmpty);
    p.dispose();
    await store.close();
  });
  test(
      'daily limit survives a recreated provider and manual commands cannot reset it',
      () async {
    final store = readyStore();
    final time = now();
    final previous = PumpPolicy.next(
        previous: null,
        commandId: 'previous-command',
        now: time - 7200000,
        requestedState: true,
        automatic: true,
        seconds: 15)!
      ..['dayStart'] = time - time % PumpPolicy.dayMs
      ..['autoCount'] = 3;
    store.seed('pumpCommands/s1', previous);
    store.seed('pumpStatus/s1', {
      'protocolVersion': 2,
      'commandId': 'previous-command',
      'state': 'completed',
      'actualState': false,
      'updatedAt': now()
    });
    var p = await hardware(store);
    p.dispose();
    p = await hardware(store);
    expect(
        await p.requestPumpState(
            sensorId: 's1', requestedState: true, automatic: true),
        isFalse);
    expect(
        await p.requestPumpState(sensorId: 's1', requestedState: true), isTrue);
    expect((store.value('pumpCommands/s1') as Map)['autoCount'], 3);
    p.dispose();
    await store.close();
  });
  test('day rollover preserves cooldown across midnight', () {
    final midnight = DateTime.utc(2026, 11, 24).millisecondsSinceEpoch;
    final old = {
      'dayStart': midnight - PumpPolicy.dayMs,
      'autoCount': 3,
      'lastAutoAt': midnight - 60000
    };
    expect(
        PumpPolicy.next(
            previous: old,
            commandId: 'next-command',
            now: midnight + 60000,
            requestedState: true,
            automatic: true,
            seconds: 15),
        isNull);
    final next = PumpPolicy.next(
        previous: old,
        commandId: 'next-command',
        now: midnight + PumpPolicy.cooldownMs,
        requestedState: true,
        automatic: true,
        seconds: 15)!;
    expect(next['autoCount'], 1);
    expect(next['dayStart'], midnight);
  });
  test('switching task mode never archives live tasks from a simulated reading',
      () async {
    final store = readyStore();
    store.seed('users/user-a/todos', {
      'auto_water_p1': {
        'userId': 'user-a',
        'title': 'Live task',
        'plantId': 'p1',
        'isAuto': true,
        'isCompleted': false,
        'dueTimestamp': now(),
      }
    });
    final todos = TodoProvider(store: store);
    final sensor = SensorData.fromMap('s1', packet(moisture: 5));
    todos.onTelemetryOrPlantsUpdated([plant()], {'s1': sensor},
        isHardwareMode: true);
    await settle();
    store.writes.clear();
    todos.onTelemetryOrPlantsUpdated([
      plant()
    ], {
      's1': SensorData.fromMap('s1', packet(moisture: 80), isSimulated: true)
    });
    await settle();
    expect(store.writes, isEmpty);
    expect(
        (store.value('users/user-a/todos') as Map).containsKey('auto_water_p1'),
        isTrue);
    todos.dispose();
    await store.close();
  });
}
