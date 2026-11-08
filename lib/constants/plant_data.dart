class PlantInfo {
  final String name;
  final String category;
  final int minMoisture;
  final String imageUrl;
  final String description;
  final String watering;
  final String light;
  final String temperature;

  const PlantInfo({
    required this.name,
    required this.category,
    required this.minMoisture,
    required this.imageUrl,
    required this.description,
    required this.watering,
    required this.light,
    required this.temperature,
  });
}

class PlantData {
  static const List<PlantInfo> catalog = [
    PlantInfo(
      name: 'Orkide',
      category: 'İç Mekan',
      minMoisture: 30,
      imageUrl: 'https://images.unsplash.com/photo-1566907225472-514215c9e5cd?auto=format&fit=crop&q=80&w=600',
      description: 'Orkideler zarafetin simgesidir. Köklerinin hava almasını severler.',
      watering: 'Haftada bir daldırma yöntemiyle sulayın.',
      light: 'Filtrelenmiş bol ışık sever.',
      temperature: 'Nemli ve ılık ortamları sever.',
    ),
    PlantInfo(
      name: 'Kaktüs',
      category: 'Kaktüsler',
      minMoisture: 30,
      imageUrl: 'https://images.unsplash.com/photo-1459411552884-841db9b3cc2a?auto=format&fit=crop&q=80&w=600',
      description: 'Dayanıklı çöl bitkileridir, suyu gövdelerinde depolarlar.',
      watering: 'Kışın ayda bir, yazın 2 haftada bir.',
      light: 'Bol güneş ışığına bayılır.',
      temperature: 'Sıcağı sever, soğuktan koruyun.',
    ),
    PlantInfo(
      name: 'Monstera (Deve Tabanı)',
      category: 'İç Mekan',
      minMoisture: 40,
      imageUrl: 'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?auto=format&fit=crop&q=80&w=600',
      description: 'Geniş ve delikli yapraklarıyla tropikal bir salon bitkisidir.',
      watering: 'Toprak üst yüzeyi kurudukça sulayın.',
      light: 'Dolaylı parlak ışık sever.',
      temperature: '18-27°C arası idealdir.',
    ),
    PlantInfo(
      name: 'Aloe Vera',
      category: 'Kaktüsler',
      minMoisture: 25,
      imageUrl: 'https://images.unsplash.com/photo-1596547609652-9cf5d8d76921?auto=format&fit=crop&q=80&w=600',
      description: 'Yapraklarındaki jel ile bilinen dayanıklı ve şifalı bir sukulenttir.',
      watering: 'Toprak tamamen kuruduğunda sulayın.',
      light: 'Aydınlık ve güneşli pencere önü.',
      temperature: '18-26°C oda sıcaklığı.',
    ),
    PlantInfo(
      name: 'Fesleğen',
      category: 'İç Mekan',
      minMoisture: 45,
      imageUrl: 'https://images.unsplash.com/photo-1618375569909-3c8616cf7733?auto=format&fit=crop&q=80&w=600',
      description: 'Hoş kokulu, doğal sinek ve böcek kovucu saksı bitkisidir.',
      watering: 'Toprağı nemli tutun, kurutmayın.',
      light: 'Günde 5-6 saat güneş ışığı.',
      temperature: '18-25°C ılık ortam.',
    ),
    PlantInfo(
      name: 'Paşa Kılıcı (Sansevieria)',
      category: 'İç Mekan',
      minMoisture: 20,
      imageUrl: 'https://images.unsplash.com/photo-1593482892290-f54927ae1bb6?auto=format&fit=crop&q=80&w=600',
      description: 'Geceleri oksijen üreten, bakımı en kolay iç mekan bitkilerinden biridir.',
      watering: '2-3 haftada bir az miktarda sulayın.',
      light: 'Yarı gölge veya aydınlık ortam.',
      temperature: '15-28°C arası her ortama uyum sağlar.',
    ),
  ];
}