class SensorConfig {
  final String sensorId;
  final int dryAdcValue; // Kuru toprak/hava ham ADC değeri (Örn: 3200)
  final int wetAdcValue; // Tam ıslak toprak ham ADC değeri (Örn: 1400)
  final int readIntervalSeconds; // ESP32 veri gönderme sıklığı (sn)
  final int maxPumpSeconds; // Donanım üstü güvenlik kapatma süresi (sn)

  const SensorConfig({
    required this.sensorId,
    this.dryAdcValue = 3200,
    this.wetAdcValue = 1400,
    this.readIntervalSeconds = 60,
    this.maxPumpSeconds = 15,
  });

  factory SensorConfig.fromMap(String sensorId, Map<dynamic, dynamic> map) {
    return SensorConfig(
      sensorId: sensorId,
      dryAdcValue: SensorData.parseSafeInt(map['dryAdcValue'], fallback: 3200),
      wetAdcValue: SensorData.parseSafeInt(map['wetAdcValue'], fallback: 1400),
      readIntervalSeconds: SensorData.parseSafeInt(map['readIntervalSeconds'], fallback: 60),
      maxPumpSeconds: SensorData.parseSafeInt(map['maxPumpSeconds'], fallback: 15),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dryAdcValue': dryAdcValue,
      'wetAdcValue': wetAdcValue,
      'readIntervalSeconds': readIntervalSeconds,
      'maxPumpSeconds': maxPumpSeconds,
    };
  }
}

class SensorData {
  final String sensorId;
  final double moisture;
  final double temperature;
  final double light;
  final int? rawAdc; // ESP32 ham analog değeri gönderirse saklanır
  final int lastUpdate;

  SensorData({
    required this.sensorId,
    required this.moisture,
    required this.temperature,
    required this.light,
    this.rawAdc,
    required this.lastUpdate,
  });

  // ESP32 String ("45.2"), int (45) veya double gönderse bile çökmeden okur
  static double parseSafeDouble(dynamic value, {required double fallback}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.').trim()) ?? fallback;
    }
    return fallback;
  }

  static int parseSafeInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  // ESP32'de NTP saati yoksa (0 veya millis() gönderirse) telefon saatini baz alır
  static int normalizeTimestamp(dynamic rawTimestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final parsed = parseSafeInt(rawTimestamp, fallback: now);

    // 2020 yılından küçük bir sayıysa (örn: ESP32 millis() değeri veya 0)
    // paketin yeni geldiğini kabul edip güncel zamanı ata
    if (parsed < 1577836800000) {
      // Saniye cinsinden Unix timestamp gönderilmişse (10 haneli) milisaniyeye çevir
      if (parsed > 1577836800) {
        return parsed * 1000;
      }
      return now;
    }
    return parsed;
  }

  factory SensorData.fromMap(String sensorId, Map<dynamic, dynamic> map) {
    return SensorData(
      sensorId: sensorId,
      moisture: parseSafeDouble(map['moisture'], fallback: 50.0).clamp(0.0, 100.0),
      temperature: parseSafeDouble(map['temperature'], fallback: 24.0),
      light: parseSafeDouble(map['light'], fallback: 60.0).clamp(0.0, 100.0),
      rawAdc: map['rawAdc'] != null ? parseSafeInt(map['rawAdc'], fallback: 0) : null,
      lastUpdate: normalizeTimestamp(map['lastUpdate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'moisture': moisture,
      'temperature': temperature,
      'light': light,
      if (rawAdc != null) 'rawAdc': rawAdc,
      'lastUpdate': lastUpdate,
    };
  }

  bool get isOnline {
    final difference = DateTime.now().millisecondsSinceEpoch - lastUpdate;
    return difference < 30 * 60 * 1000;
  }
}