import 'package:flutter_test/flutter_test.dart';
import '../lib/models/plant.dart';
import '../lib/models/sensor_data.dart';
import '../lib/services/plant_intelligence.dart';

void main() {
  group('SoilSense PlantIntelligence & Model Testleri', () {
    test('Bitki türüne göre bilimsel varsayılan profil doğru atanmalı', () {
      final cactusProfile = Plant.defaultProfileForType('Kaktüs');
      final orchidProfile = Plant.defaultProfileForType('Orkide');

      expect(cactusProfile['maxMoisture'], 60);
      expect(orchidProfile['maxMoisture'], 75);
    });

    test('İdeal sensör değerlerinde sağlık puanı 100 olmalı', () {
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

      final idealSensor = SensorData(
        sensorId: 'sensor1',
        moisture: 50.0,
        temperature: 23.0,
        light: 55.0,
        lastUpdate: DateTime.now().millisecondsSinceEpoch,
      );

      final score = PlantIntelligence.calculateHealthScore(plant, idealSensor);
      expect(score, 100);
    });

    test('Kritik düşük nemde sağlık puanı düşmeli ve KRİTİK DÜŞÜK uyarısı üretilmeli', () {
      final plant = Plant(
        id: 'p2',
        userId: 'u1',
        name: 'Monstera',
        type: 'Monstera',
        sensorId: 'sensor2',
        moistureLevel: 20.0,
        minMoisture: 40,
      );

      final drySensor = SensorData(
        sensorId: 'sensor2',
        moisture: 20.0,
        temperature: 24.0,
        light: 50.0,
        lastUpdate: DateTime.now().millisecondsSinceEpoch,
      );

      final score = PlantIntelligence.calculateHealthScore(plant, drySensor);
      final checks = PlantIntelligence.evaluateParameters(plant, drySensor);

      expect(score, lessThan(70));
      expect(checks.first.statusLabel, 'KRİTİK DÜŞÜK');
    });

    test('30 dakikadan eski sensör verisi ÇEVRİMDIŞI olarak işaretlenmeli', () {
      final oldTimestamp =
          DateTime.now().subtract(const Duration(minutes: 45)).millisecondsSinceEpoch;

      final staleSensor = SensorData(
        sensorId: 'sensor3',
        moisture: 45.0,
        temperature: 22.0,
        light: 60.0,
        lastUpdate: oldTimestamp,
      );

      expect(staleSensor.isOnline, isFalse);
      final report = PlantIntelligence.diagnoseSensor('sensor3', staleSensor);
      expect(report.statusText, 'ÇEVRİMDIŞI');
    });
  });
}