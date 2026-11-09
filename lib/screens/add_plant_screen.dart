import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/plant_data.dart';
import '../providers/plant_provider.dart';
import '../providers/sensor_provider.dart';

class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sensorController = TextEditingController();

  PlantInfo? _selectedPlant;
  int _customMinMoisture = 30;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _sensorController.dispose();
    super.dispose();
  }

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
                              _customMinMoisture = item.minMoisture;
                              if (_nameController.text.trim().isEmpty) {
                                _nameController.text = "Salonumdaki ${item.name}";
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
    final plantProvider = Provider.of<PlantProvider>(context, listen: false);
    final sensorProvider = Provider.of<SensorProvider>(context, listen: false);

    final name = _nameController.text.trim();
    final sensorId = _sensorController.text.trim();

    if (_selectedPlant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen önce bitki kütüphanesinden bir bitki türü seçin.")),
      );
      return;
    }

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen bitkinize bir isim verin.")),
      );
      return;
    }

    final duplicateName = plantProvider.plants.any(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
    );
    if (duplicateName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu isimde bir bitkiniz zaten var.")),
      );
      return;
    }

    if (sensorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen bir Sensör ID girin (Örn: sensor1).")),
      );
      return;
    }

    final duplicateSensor = plantProvider.plants.any(
      (p) => p.sensorId.toLowerCase() == sensorId.toLowerCase(),
    );
    if (duplicateSensor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu sensör başka bir saksıya bağlı! Farklı bir sensör ID girin.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Seçilen örnek sensör henüz gerçek veri göndermiyorsa sanal test verisini başlat
    await sensorProvider.ensureSensorExists(sensorId, initialMoisture: 50.0);

    final success = await plantProvider.addPlant(
      name: name,
      type: _selectedPlant!.name,
      sensorId: sensorId,
      minMoisture: _customMinMoisture,
      imageUrl: _selectedPlant!.imageUrl,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bitki kaydedilemedi. Lütfen internet bağlantınızı kontrol edin."),
          backgroundColor: AppColors.statusCritical,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final cardColor = Theme.of(context).cardColor;
    final plantProvider = Provider.of<PlantProvider>(context);
    final sensorProvider = Provider.of<SensorProvider>(context);

    final usedSensorIds = plantProvider.plants.map((p) => p.sensorId.toLowerCase()).toSet();
    final availableSensors = sensorProvider.sensors.keys
        .where((id) => !usedSensorIds.contains(id.toLowerCase()))
        .toList();

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
                // 1. BİTKİ TÜRÜ SEÇİMİ
                Text(
                  "1. Bitki Türü",
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
                      border: Border.all(
                        color: _selectedPlant != null ? AppColors.primary.withOpacity(0.4) : Colors.transparent,
                      ),
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
                            color: _selectedPlant == null ? textColor : AppColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPlant?.name ?? "Listeden Seç (Zorunlu)",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedPlant != null
                                    ? "Önerilen Minimum Nem: %${_selectedPlant!.minMoisture}"
                                    : "Dokunarak bitki kütüphanesini aç",
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

                const SizedBox(height: 24),

                // 2. BİTKİNİN ADI
                Text(
                  "2. Bitkinin Adı",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
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
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    style: TextStyle(color: textColor),
                    decoration: const InputDecoration(
                      icon: Icon(Icons.edit, color: AppColors.primary, size: 22),
                      hintText: "Örn: Salonumdaki Orkide",
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 3. SENSÖR EŞLEŞTİRME
                Text(
                  "3. Sensör Eşleştir (ID)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
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
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: textColor),
                    decoration: const InputDecoration(
                      icon: Icon(Icons.sensors, color: AppColors.primary, size: 22),
                      hintText: "Örn: sensor1",
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (availableSensors.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    "Boştaki Aktif Sensörler (Seçmek için dokunun):",
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableSensors.map((sId) {
                      final isSelected = _sensorController.text.trim() == sId;
                      return ActionChip(
                        backgroundColor: isSelected ? AppColors.primary : cardColor,
                        label: Text(
                          sId,
                          style: TextStyle(
                            color: isSelected ? Colors.white : textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        avatar: Icon(
                          Icons.wifi,
                          size: 16,
                          color: isSelected ? Colors.white : AppColors.statusGood,
                        ),
                        onPressed: () {
                          setState(() => _sensorController.text = sId);
                        },
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 24),

                // 4. BAKIM AYARLARI (MİNİMUM NEM SINIRI)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "4. Kritik Nem Sınırı",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    Text(
                      "%$_customMinMoisture",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _customMinMoisture.toDouble(),
                  min: 10,
                  max: 80,
                  divisions: 14,
                  activeColor: AppColors.primary,
                  label: "%$_customMinMoisture",
                  onChanged: (val) => setState(() => _customMinMoisture = val.round()),
                ),

                const SizedBox(height: 28),

                // 5. KAYDET VE TEST ET BUTONU
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
                            "Kaydet ve Eşleştir",
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