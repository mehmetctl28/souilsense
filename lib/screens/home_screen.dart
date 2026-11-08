import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plant_provider.dart';
import '../providers/todo_provider.dart';
import '../providers/auth_provider.dart';
import '../models/plant.dart';
import '../constants/colors.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/todo_list.dart';
import 'add_plant_screen.dart';
import 'plant_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Kritik seviyedeki bitkileri gösteren alt pencere
  void _showCriticalPlantsSheet(BuildContext context, List<Plant> thirstyPlants) {
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
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset > 0 ? bottomInset + 12 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.statusCritical, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      "${thirstyPlants.length} Bitki İlgi Bekliyor",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "Aşağıdaki bitkilerin değerleri kritik seviyede:",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: thirstyPlants.length,
                    itemBuilder: (context, index) {
                      final plant = thirstyPlants[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plant.id)),
                          );
                        },
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.statusCritical.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: (plant.imageUrl != null && plant.imageUrl!.isNotEmpty)
                                ? Image.network(
                                    plant.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                        title: Text(
                          plant.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                        ),
                        subtitle: Text(
                          "Nem: %${plant.moistureLevel.toInt()} (Sınır: \%${plant.minMoisture})",
                          style: const TextStyle(color: AppColors.statusCritical, fontWeight: FontWeight.w500),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      );
                    },
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
    final plantProvider = Provider.of<PlantProvider>(context);
    final todoProvider = Provider.of<TodoProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context);

    final plants = plantProvider.plants;
    final thirstyPlants = plants.where((p) => p.moistureLevel < p.minMoisture).toList();

    // Otomatik sulama görevlerini senkronize et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      todoProvider.syncAutoTasks(plants);
    });

    final userName = authProvider.currentUser?.displayName ?? "";
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. ÜST BAR (SoilSense & Ayarlar İkonu) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SoilSense",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text(
                          userName.isNotEmpty ? "Merhaba, $userName 👋" : "Merhaba, 👋",
                          style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.settings_outlined, color: textColor, size: 28),
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // --- 2. DURUM KARTI (Kritik veya İyi Durum) ---
                if (thirstyPlants.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB5483A), Color(0xFFD9824B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB5483A).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Bakım Bekleyenler Var!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "${thirstyPlants.length} bitkinin değerleri kritik seviyede.",
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => _showCriticalPlantsSheet(context, thirstyPlants),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Şimdi Kontrol Et", style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
                            SizedBox(width: 10),
                            Text(
                              "Her Şey Yolunda!",
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Tüm bitkilerinin nem ve sıcaklık değerleri ideal seviyede.",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 28),

                // --- 3. HIZLI İŞLEMLER ---
                Text(
                  "Hızlı İşlemler",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    QuickActionButton(
                      icon: Icons.add,
                      label: "Bitki Ekle",
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddPlantScreen()),
                        );
                      },
                    ),
                    QuickActionButton(
                      icon: Icons.water_drop_outlined,
                      label: "Sulama",
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        if (thirstyPlants.isNotEmpty) {
                          _showCriticalPlantsSheet(context, thirstyPlants);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Şu an suya ihtiyacı olan bitki yok.")),
                          );
                        }
                      },
                    ),
                    QuickActionButton(
                      icon: Icons.history,
                      label: "Geçmiş",
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Sulama geçmişi güncel.")),
                        );
                      },
                    ),
                    QuickActionButton(
                      icon: Icons.lightbulb_outline,
                      label: "İpuçları",
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Sol alttaki Keşfet sekmesinden ipuçlarına ulaşabilirsin.")),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // --- 4. BUGÜNÜN PLANI (TODO LIST) ---
                const TodoList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}