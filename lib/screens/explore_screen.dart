import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/plant_data.dart';
import 'add_plant_screen.dart';

class ExploreArticle {
  final String title;
  final String category;
  final String summary;
  final String imageUrl;
  final List<String> bulletPoints;

  const ExploreArticle({
    required this.title,
    required this.category,
    required this.summary,
    required this.imageUrl,
    required this.bulletPoints,
  });
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _searchQuery = "";
  String _selectedCategory = "Tümü";

  final List<String> _categories = const [
    "Tümü",
    "İç Mekan",
    "Kaktüsler",
    "Sulama",
    "Hastalıklar",
    "Mevsimsel",
  ];

  final List<ExploreArticle> _articles = const [
    ExploreArticle(
      title: "Yaprakları Neden Sararıyor?",
      category: "Sulama",
      summary: "Bitkilerde yaprak sararmasının en yaygın 4 nedeni ve sensör verileriyle erken teşhis yöntemleri.",
      imageUrl: "https://images.unsplash.com/photo-1457369804613-52c61a468e7d?auto=format&fit=crop&w=800&q=80",
      bulletPoints: [
        "Aşırı Sulama: Toprak nemi sürekli %75 üzerinde kalıyorsa kökler oksijensiz kalır ve alt yapraklar sararır.",
        "Yetersiz Nem: Toprak nemi uzun süre %20 altında kaldığında bitki su kaybını azaltmak için yaprak döker.",
        "Işık Eksikliği: Günlük ışık seviyesi düşük olan iç mekan bitkilerinde fotosentez yavaşlar.",
        "Ani Sıcaklık Değişimi: Klima veya kalorifer yakınına konulan bitkilerde termal stres oluşur.",
      ],
    ),
    ExploreArticle(
      title: "Ofis ve İç Mekan Bitkileri Rehberi",
      category: "İç Mekan",
      summary: "Düşük ve orta ışık koşullarında yüksek performans gösteren dayanıklı iç mekan bitkileri.",
      imageUrl: "https://images.unsplash.com/photo-1614594975525-e45190c55d0b?auto=format&fit=crop&w=600&q=80",
      bulletPoints: [
        "Monstera (Deve Tabanı): %40 minimum nem sınırı ve filtrelenmiş gün ışığı ile hızlı gelişir.",
        "Paşa Kılıcı: Düşük ışıkta bile yaşayabilir, toprağı tamamen kuruyana kadar sulanmamalıdır.",
        "Orkide: Köklerinin hava alması gerekir; haftada bir daldırma yöntemiyle sulanmalıdır.",
      ],
    ),
    ExploreArticle(
      title: "Kaktüs ve Sukulent Bakımı",
      category: "Kaktüsler",
      summary: "Çöl kökenli bitkilerde kök çürümesini önleyen doğru sulama ve toprak drenajı kuralları.",
      imageUrl: "https://images.unsplash.com/photo-1509423350716-97f9360b4e09?auto=format&fit=crop&w=600&q=80",
      bulletPoints: [
        "Toprak nemi %20-%25 seviyesinin altına düşmeden sulama yapmayın.",
        "Kış aylarında büyüme durduğu için sulama sıklığını ayda bire indirin.",
        "Güney cepheli, doğrudan güneş alan pencereleri tercih edin.",
      ],
    ),
    ExploreArticle(
      title: "Bitki Hastalıkları ve Belirtileri",
      category: "Hastalıklar",
      summary: "Yaprak uçlarında kahverengileşme, beyaz lekeler ve kök çürümesine karşı erken müdahale.",
      imageUrl: "https://images.unsplash.com/photo-1416879595882-3373a0480b5b?auto=format&fit=crop&w=600&q=80",
      bulletPoints: [
        "Yaprak Ucu Yanması: Ortam neminin düşüklüğü veya şebeke suyundaki kireçten kaynaklanır.",
        "Beyaz Pamuksu Lekeler (Unlu Bit): Nemli bezle temizleyin ve neem yağı uygulayın.",
        "Kök Çürümesi: Saksı altındaki drenaj deliklerinin açık olduğundan emin olun.",
      ],
    ),
    ExploreArticle(
      title: "Mevsimsel Bakım Takvimi",
      category: "Mevsimsel",
      summary: "İlkbahar büyüme dönemi ve kış dinlenme döneminde sulama/gübreleme geçişleri.",
      imageUrl: "https://images.unsplash.com/photo-1466692476868-aef1dfb1e735?auto=format&fit=crop&w=600&q=80",
      bulletPoints: [
        "İlkbahar & Yaz: Aktif büyüme dönemidir, ayda 2 kez sıvı bitki besini verilebilir.",
        "Sonbahar & Kış: Buharlaşma azaldığı için minimum nem eşiğini %5 daha düşük tutabilirsiniz.",
      ],
    ),
  ];

  void _openArticleSheet(ExploreArticle article) {
    FocusManager.instance.primaryFocus?.unfocus();
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.78,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    article.imageUrl,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: AppColors.primary.withOpacity(0.15),
                      child: const Icon(Icons.menu_book, size: 48, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      article.category,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  article.title,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 10),
                Text(
                  article.summary,
                  style: TextStyle(fontSize: 15, color: textColor.withOpacity(0.8), height: 1.5),
                ),
                const SizedBox(height: 20),
                Text(
                  "Önemli Bakım Adımları",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),
                ...article.bulletPoints.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            point,
                            style: TextStyle(fontSize: 14, color: textColor, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPlantCatalogDetail(PlantInfo plant) {
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        plant.imageUrl,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 68,
                          height: 68,
                          color: AppColors.primary.withOpacity(0.15),
                          child: const Icon(Icons.local_florist, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plant.name,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "İdeal Minimum Nem: %${plant.minMoisture}",
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(plant.description, style: TextStyle(color: textColor.withOpacity(0.8), height: 1.4)),
                const SizedBox(height: 16),
                Text("💧 Sulama: ${plant.watering}", style: TextStyle(color: textColor, fontSize: 13)),
                const SizedBox(height: 8),
                Text("☀️ Işık: ${plant.light}", style: TextStyle(color: textColor, fontSize: 13)),
                const SizedBox(height: 8),
                Text("🌡️ Sıcaklık: ${plant.temperature}", style: TextStyle(color: textColor, fontSize: 13)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddPlantScreen()),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      "Bu Bitkiyi Bahçeme Ekle",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final cardColor = Theme.of(context).cardColor;

    final filteredArticles = _articles.where((a) {
      final matchesCategory = _selectedCategory == "Tümü" || a.category == _selectedCategory;
      final matchesQuery = a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.summary.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

    final filteredCatalog = PlantData.catalog.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final featuredArticle = _articles.first;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ARAMA ÇUBUĞU
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search, color: Colors.grey),
                    hintText: "Bitki, ipucu veya makale ara...",
                    hintStyle: TextStyle(color: Colors.grey),
                    suffixIcon: Icon(Icons.tune, color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 2. KATEGORİ BUTONLARI
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : cardColor,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : textColor.withOpacity(0.75),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // 3. GÜNÜN İPUCU (TIKLANABİLİR DETAY EKRANI)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Günün İpucu 💡",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.grey),
                    onPressed: () => _openArticleSheet(featuredArticle),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _openArticleSheet(featuredArticle),
                child: Container(
                  height: 210,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    image: DecorationImage(
                      image: NetworkImage(featuredArticle.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.15),
                          Colors.black.withOpacity(0.75),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            featuredArticle.category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          featuredArticle.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            Text(
                              "Devamını Oku",
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.chevron_right, color: Colors.white70, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 4. İLHAM AL & BAKIM REHBERLERİ (FİLTRELENEBİLİR VE AÇILABİLİR)
              Text(
                "İlham Al ✨",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 14),
              if (filteredArticles.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text("Aramanıza uygun rehber bulunamadı.", style: TextStyle(color: Colors.grey)),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredArticles.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    final article = filteredArticles[index];
                    return GestureDetector(
                      onTap: () => _openArticleSheet(article),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                                child: Image.network(
                                  article.imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.primary.withOpacity(0.1),
                                    child: const Icon(Icons.menu_book, color: AppColors.primary),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article.category,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    article.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 28),

              // 5. BİTKİ KÜTÜPHANESİ ENTEGRASYONU
              Text(
                "Bitki Kütüphanesi 🌿",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 12),
              ...filteredCatalog.map((plant) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    onTap: () => _openPlantCatalogDetail(plant),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        plant.imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.local_florist, color: AppColors.primary),
                      ),
                    ),
                    title: Text(
                      plant.name,
                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                    ),
                    subtitle: Text(
                      "İdeal Nem: %${plant.minMoisture} • ${plant.light}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}