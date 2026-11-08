import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/plant_data.dart';
import '../providers/plant_provider.dart';

class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sensorController = TextEditingController();

  PlantInfo? _selectedPlant;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _sensorController.dispose();
    super.dispose();
  }

  // "Listeden Seç" kartına dokununca açılan bitki kütüphanesi
  void _openCatalogSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

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
            heightFactor: 0.65,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, bottomInset > 0 ? bottomInset + 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bitki Kütüphanesi",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: PlantData.catalog.length,
                      itemBuilder: (context, index) {
                        final item = PlantData.catalog[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              item.imageUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.local_florist, color: AppColors.primary),
                              ),
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                          ),
                          subtitle: Text(
                            "İdeal Nem Sınırı: %${item.minMoisture}",
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            setState(() {
                              _selectedPlant = item;
                              if (_nameController.text.isEmpty) {
                                _nameController.text = item.name.toLowerCase();
                              }
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _savePlant() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen bitkinin adını girin.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    final plantInfo = _selectedPlant ?? PlantData.catalog.first;
    await Provider.of<PlantProvider>(context, listen: false).addPlant(
      name: name,
      type: plantInfo.name,
      sensorId: _sensorController.text.trim(),
      minMoisture: plantInfo.minMoisture,
      imageUrl: plantInfo.imageUrl,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final cardColor = Theme.of(context).cardColor;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor),
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context);
            },
          ),
          title: Text(
            "Yeni Bitki Ekle",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: textColor),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. BİTKİ TÜRÜ (LİSTEDEN SEÇ) ---
                Text(
                  "Bitki Türü",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _openCatalogSheet,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _selectedPlant == null ? Icons.search : Icons.local_florist,
                            color: textColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPlant?.name ?? "Listeden Seç",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedPlant != null
                                    ? "Nem Sınırı: %${_selectedPlant!.minMoisture}"
                                    : "Dokunarak kütüphaneyi aç",
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // --- 2. BİTKİNİN ADI ---
                const Text(
                  "Bitkinin Adı",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    controller: _nameController,
                    autofocus: false,
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    style: TextStyle(color: textColor),
                    decoration: const InputDecoration(
                      icon: Icon(Icons.edit, color: AppColors.primary, size: 22),
                      hintText: "Örn: Ofis Çiçeğim",
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // --- 3. SENSÖR KİMLİĞİ (ID) ---
                const Text(
                  "Sensör Kimliği (ID)",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    controller: _sensorController,
                    autofocus: false,
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    style: TextStyle(color: textColor),
                    decoration: const InputDecoration(
                      icon: Icon(Icons.qr_code, color: AppColors.primary, size: 22),
                      hintText: "Cihaz üzerindeki kodu girin",
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // --- 4. BİTKİYİ OLUŞTUR BUTONU ---
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _savePlant,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 4,
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Bitkiyi Oluştur",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}