class SensorData {
  final String sensorId;
  final double moisture;
  final double temperature;
  final double light;
  final int lastUpdate;

  SensorData({
    required this.sensorId,
    required this.moisture,
    required this.temperature,
    required this.light,
    required this.lastUpdate,
  });

  factory SensorData.fromMap(String sensorId, Map<dynamic, dynamic> map) {
    return SensorData(
      sensorId: sensorId,
      moisture: (map['moisture'] ?? 50.0).toDouble(),
      temperature: (map['temperature'] ?? 24.0).toDouble(),
      light: (map['light'] ?? 60.0).toDouble(),
      lastUpdate: (map['lastUpdate'] ?? DateTime.now().millisecondsSinceEpoch).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'moisture': moisture,
      'temperature': temperature,
      'light': light,
      'lastUpdate': lastUpdate,
    };
  }

  // Sensörün son veriyi gönderdiği zamandan bu yana çok süre geçip geçmediğini kontrol et (Örn: 30 dk)
  bool get isOnline {
    final difference = DateTime.now().millisecondsSinceEpoch - lastUpdate;
    return difference < 30 * 60 * 1000; // 30 dakika
  }
}