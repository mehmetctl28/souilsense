class Plant {
  final String id;
  final String userId;
  final String name;
  final String type;
  final String sensorId;
  final double moistureLevel;
  final int minMoisture;
  final int maxMoisture;
  final double temperature;
  final double minTemp;
  final double maxTemp;
  final double lightLevel;
  final double minLight;
  final double maxLight;
  final bool isPumpOn;
  final String? imageUrl;

  Plant({
    required this.id,
    required this.userId,
    required this.name,
    this.type = 'Genel',
    required this.sensorId,
    required this.moistureLevel,
    required this.minMoisture,
    this.maxMoisture = 80,
    this.temperature = 24.0,
    this.minTemp = 18.0,
    this.maxTemp = 28.0,
    this.lightLevel = 60.0,
    this.minLight = 25.0,
    this.maxLight = 85.0,
    this.isPumpOn = false,
    this.imageUrl,
  });

  // Bitki türüne göre varsayılan bilimsel profil eşikleri
  static Map<String, num> defaultProfileForType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('kaktüs') || lower.contains('aloe')) {
      return {'maxMoisture': 60, 'minTemp': 15.0, 'maxTemp': 34.0, 'minLight': 45.0, 'maxLight': 95.0};
    } else if (lower.contains('orkide') || lower.contains('monstera')) {
      return {'maxMoisture': 75, 'minTemp': 19.0, 'maxTemp': 27.0, 'minLight': 30.0, 'maxLight': 75.0};
    }
    return {'maxMoisture': 80, 'minTemp': 18.0, 'maxTemp': 28.0, 'minLight': 25.0, 'maxLight': 85.0};
  }

  factory Plant.fromMap(String id, Map<dynamic, dynamic> map) {
    final String plantType = (map['type'] ?? map['name'] ?? 'Genel').toString();
    final defaults = defaultProfileForType(plantType);

    return Plant(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      name: (map['name'] ?? 'İsimsiz Bitki').toString(),
      type: plantType,
      sensorId: (map['sensorId'] ?? '').toString(),
      moistureLevel: (map['moistureLevel'] ?? 50.0).toDouble(),
      minMoisture: (map['minMoisture'] ?? 30).toInt(),
      maxMoisture: (map['maxMoisture'] ?? defaults['maxMoisture']!).toInt(),
      temperature: (map['temperature'] ?? 24.0).toDouble(),
      minTemp: (map['minTemp'] ?? defaults['minTemp']!).toDouble(),
      maxTemp: (map['maxTemp'] ?? defaults['maxTemp']!).toDouble(),
      lightLevel: (map['lightLevel'] ?? 60.0).toDouble(),
      minLight: (map['minLight'] ?? defaults['minLight']!).toDouble(),
      maxLight: (map['maxLight'] ?? defaults['maxLight']!).toDouble(),
      isPumpOn: map['isPumpOn'] == true,
      imageUrl: map['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'type': type,
      'sensorId': sensorId,
      'moistureLevel': moistureLevel,
      'minMoisture': minMoisture,
      'maxMoisture': maxMoisture,
      'temperature': temperature,
      'minTemp': minTemp,
      'maxTemp': maxTemp,
      'lightLevel': lightLevel,
      'minLight': minLight,
      'maxLight': maxLight,
      'isPumpOn': isPumpOn,
      'imageUrl': imageUrl,
    };
  }
}