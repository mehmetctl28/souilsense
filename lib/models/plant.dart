class Plant {
  final String id;
  final String userId;
  final String name;
  final String type;
  final String sensorId;
  final double moistureLevel;
  final int minMoisture;
  final double temperature;
  final double lightLevel;
  final bool isPumpOn;
  final String? imageUrl;

  Plant({
    required this.id,
    required this.userId,
    required this.name,
    this.type = 'Genel',
    this.sensorId = '',
    this.moistureLevel = 50.0,
    this.minMoisture = 30,
    this.temperature = 0.0,
    this.lightLevel = 0.0,
    this.isPumpOn = false,
    this.imageUrl,
  });

  factory Plant.fromMap(String id, Map<dynamic, dynamic> map) {
    return Plant(
      id: id,
      userId: map['userId']?.toString() ?? '',
      name: map['name']?.toString() ?? 'İsimsiz Bitki',
      type: map['type']?.toString() ?? 'Genel',
      sensorId: map['sensorId']?.toString() ?? '',
      moistureLevel: (map['moistureLevel'] ?? 50).toDouble(),
      minMoisture: (map['minMoisture'] ?? 30).toInt(),
      temperature: (map['temperature'] ?? 0.0).toDouble(),
      lightLevel: (map['lightLevel'] ?? 0.0).toDouble(),
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
      'temperature': temperature,
      'lightLevel': lightLevel,
      'isPumpOn': isPumpOn,
      'imageUrl': imageUrl,
    };
  }
}