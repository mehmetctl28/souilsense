import 'package:flutter_test/flutter_test.dart';
import '../lib/models/plant.dart';
import '../lib/models/sensor_data.dart';
import '../lib/services/plant_intelligence.dart';

void main() {
  group('SoilSense Donanım, Telemetri ve Zeka 2.0 Testleri', () {
    test('1. Bitki türüne göre bilimsel varsayılan profil doğru atanmalı', () {
      final cactusProfile = Plant.defaultProfileForType('Kaktüs');
      final orchidProfile = Plant.defaultProfileForType('Orkide');

      expect(cactusProfile['maxMoisture'], 60);
      expect(orchidProfile['maxMoisture'], 75);
    });

    test('2. Ham ADC değeri kalibrasyon sınırlarına göre doğru yüzdeye çevrilmeli', () {
      const config = SensorConfig(
        sensorId: 'sensor1',
        dryAdcValue: 3200, // %0 nem
        wetAdcValue: 1400, // %100 nem
      );

      expect(config.convertAdcToMoisture(3200), 0.0);
      expect(config.convertAdcToMoisture(1400), 100.0);
      expect(config.convertAdcToMoisture(2300), 50.0);
    });

    test('3. ESP32 eksik veya saniye cinsinden timestamp gönderdiğinde normalize edilmeli', () {
      // 0 gönderildiğinde eksik veri olarak 0 dönmeli
      expect(SensorData.normalizeTimestamp(0), 0);

      // 10 haneli saniye cinsinden Unix timestamp milisaniyeye (13 hane) çevrilmeli
      expect(SensorData.normalizeTimestamp(1700000000), 1700000000000);
    });

    test('4. İdeal ve güncel sensör verisinde sağlık skoru 100 ve güncel olmalı', () {
      final plant = Plant(
        id: 'p1',
        userId: 'u1',
        name: 'Salon Orkidem',
        type: 'Orkide',
        sensorId: 'sensor1',
        moistureLevel: 50.0,
        minMoisture: 30,
        maxMoisture: 75,
        minTemp: 19.0,
        maxTemp: 27.0,
        minLight: 30.0,
        maxLight: 75.0,
      );

      final freshSensor = SensorData(
        sensorId: 'sensor1',
        moisture: 50.0,
        temperature: 23.0,
        light: 55.0,
        lastUpdate: DateTime.now().millisecondsSinceEpoch,
      );

      final result = PlantIntelligence.evaluateHealthScore(plant, freshSensor);
      expect(result.score, 100);
      expect(result.isFresh, isTrue);
      expect(result.label, contains('Güncel Sağlık'));
    });

    test('5. Eski (çevrimdışı) sensör verisinde sağlık skoru Son Bilinen Ölçüme Göre olarak etiketlenmeli', () {
      final plant = Plant(
        id: 'p2',
        userId: 'u1',
        name: 'Monstera',
        type: 'Monstera',
        sensorId: 'sensor2',
        moistureLevel: 50.0,
        minMoisture: 35,
      );

      final staleTimestamp =
          DateTime.now().subtract(const Duration(minutes: 45)).millisecondsSinceEpoch;

      final staleSensor = SensorData(
        sensorId: 'sensor2',
        moisture: 50.0,
        temperature: 24.0,
        light: 50.0,
        lastUpdate: staleTimestamp,
      );

      final result = PlantIntelligence.evaluateHealthScore(
        plant,
        staleSensor,
        offlineTimeoutMinutes: 30,
      );
      expect(result.isFresh, isFalse);
      expect(result.label, contains('Son Bilinen Ölçüme Göre'));
    });

    test('6. Gerçek timestamp farkına göre saatlik kuruma hızı doğru hesaplanmalı', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final twoHoursAgo = now - (2 * 3600 * 1000);

      final history = [
        TelemetryPoint(timestamp: twoHoursAgo, moisture: 50.0, temperature: 24.0, light: 60.0),
        TelemetryPoint(timestamp: now, moisture: 40.0, temperature: 24.0, light: 60.0),
      ];

      // 2 saatte %10 düşüş -> saatte %5.0 kuruma hızı, %30 eşiğine 2 saat kalmalı
      final analysis = PlantIntelligence.analyzeDryingRate(history, 40.0, 30);
      expect(analysis.canPredict, isTrue);
      expect(analysis.dropPerHour, closeTo(5.0, 0.1));
      expect(analysis.hoursUntilCritical, closeTo(2.0, 0.1));
    });

    test('7. Uzun süre hiç değişmeyen 5 ardışık ölçümde SABİT / DONMUŞ VERİ uyarısı verilmeli', () {
      final baseTime = DateTime.now().subtract(const Duration(minutes: 60)).millisecondsSinceEpoch;
      final frozenHistory = List.generate(
        5,
        (i) => TelemetryPoint(
          timestamp: baseTime + (i * 10 * 60 * 1000), // 10'ar dakika arayla 40 dk
          moisture: 48.0,
          temperature: 24.0,
          light: 60.0,
        ),
      );

      final currentSensor = SensorData(
        sensorId: 'sensor_frozen',
        moisture: 48.0,
        temperature: 24.0,
        light: 60.0,
        lastUpdate: DateTime.now().millisecondsSinceEpoch,
      );

      final report = PlantIntelligence.diagnoseSensor(
        'sensor_frozen',
        currentSensor,
        history: frozenHistory,
      );
      expect(report.statusText, 'SABİT / DONMUŞ VERİ');
      expect(report.isHealthy, isFalse);
    });
  });
}