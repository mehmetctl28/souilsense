import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/sensor_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _showEditProfileDialog(AuthProvider authProvider) async {
    final controller = TextEditingController(text: authProvider.currentUser?.displayName ?? "");
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Profili Düzenle", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: textColor),
          decoration: const InputDecoration(
            labelText: "Ad Soyad / Kullanıcı Adı",
            hintText: "Örn: Mehmet",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && authProvider.currentUser != null) {
                await authProvider.currentUser!.updateDisplayName(newName);
                await authProvider.currentUser!.reload();
                if (mounted) setState(() {});
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSensorAndPumpSettings() async {
    final sensorProvider = Provider.of<SensorProvider>(context, listen: false);
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final cardColor = Theme.of(context).cardColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        int tempPump = sensorProvider.maxPumpSeconds;
        int tempOffline = sensorProvider.offlineTimeoutMinutes;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sensör ve Pompa Güvenlik Sınırları",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Maksimum Pompa Çalışma Süresi: $tempPump sn",
                      style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                    ),
                    Slider(
                      value: tempPump.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setModalState(() => tempPump = v.round()),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sensör Çevrimdışı Uyarı Eşiği: $tempOffline dk",
                      style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                    ),
                    Slider(
                      value: tempOffline.toDouble(),
                      min: 10,
                      max: 120,
                      divisions: 11,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setModalState(() => tempOffline = v.round()),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () async {
                          await sensorProvider.updateSafetySettings(
                            maxPumpSeconds: tempPump,
                            offlineTimeoutMinutes: tempOffline,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text(
                          "Kaydet ve Cihazlara Uygula",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPrivacyPolicy() {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "Veri Mimarisi ve Güvenlik Politikası",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: const SingleChildScrollView(
          child: Text(
            "1. Kullanıcı Verileri (users/{uid}): Bitki profilleriniz, görevleriniz ve ayrıştırılmış geçmiş kayıtlarınız (sensorHistory, wateringEvents, alerts) yalnızca kendi UID düğümünüz altında tutulur.\n\n"
            "2. Donanım Yetkilendirmesi (sensorOwners/{sensorId}): Uygulama tüm sensör ağını dinlemez; yalnızca bitkilerinize eşleştirdiğiniz sensör ve pompa düğümlerine bireysel abonelik açar.\n\n"
            "3. Simülasyon Ayrımı: Donanım modu aktifken uygulama tarafından fiziksel sensör düğümlerine hiçbir simülasyon verisi yazılmaz.",
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tamam")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final sensorProvider = Provider.of<SensorProvider>(context);
    final user = authProvider.currentUser;

    final email = user?.email ?? "kullanici@soilsense.com";
    final displayName = user?.displayName ?? "Bahçe Sahibi";
    final initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : "U");

    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Ayarlar",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: textColor),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () => _showEditProfileDialog(authProvider),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  "Bildirim & Görünüm",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.notifications_active_outlined,
                      title: "Kritik Bakım Bildirimleri",
                      subtitle: sensorProvider.notificationsEnabled
                          ? "Aktif: Kritik nem ve pompa uyarıları anlık gösterilir"
                          : "Kapalı: Anlık uyarı pencereleri susturuldu",
                      value: sensorProvider.notificationsEnabled,
                      textColor: textColor,
                      onChanged: (val) => sensorProvider.setNotificationsEnabled(val),
                    ),
                    if (sensorProvider.notificationsEnabled) ...[
                      Divider(height: 1, indent: 64, color: Colors.grey.withOpacity(0.15)),
                      _buildActionTile(
                        icon: Icons.notification_important_outlined,
                        title: "Bildirim Sistemini Test Et",
                        trailingText: "Gönder",
                        textColor: textColor,
                        onTap: () {
                          sensorProvider.triggerTestNotification();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "🔔 SoilSense Test Bildirimi: Kritik nem ve donanım uyarı kanalı aktif.",
                              ),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                      ),
                    ],
                    Divider(height: 1, indent: 64, color: Colors.grey.withOpacity(0.15)),
                    _buildSwitchTile(
                      icon: Icons.dark_mode_outlined,
                      title: "Karanlık Mod",
                      subtitle: "Tema tercihiniz cihazda kalıcı olarak saklanır",
                      value: themeProvider.isDarkMode,
                      textColor: textColor,
                      onChanged: (val) => themeProvider.toggleTheme(val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  "Donanım & Güvenlik",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.memory,
                      title: "Gerçek ESP32 Donanım Modu",
                      subtitle: sensorProvider.isHardwareMode
                          ? "Aktif: Yalnızca fiziksel ESP32 verileri okunur"
                          : "Simülasyon Modu: Sanal test sensörleri aktif",
                      value: sensorProvider.isHardwareMode,
                      textColor: textColor,
                      onChanged: (val) => sensorProvider.setHardwareMode(val),
                    ),
                    Divider(height: 1, indent: 64, color: Colors.grey.withOpacity(0.15)),
                    _buildActionTile(
                      icon: Icons.sensors,
                      title: "Pompa ve Çevrimdışı Sınırları",
                      trailingText:
                          "${sensorProvider.maxPumpSeconds}sn / ${sensorProvider.offlineTimeoutMinutes}dk",
                      textColor: textColor,
                      onTap: _showSensorAndPumpSettings,
                    ),
                    Divider(height: 1, indent: 64, color: Colors.grey.withOpacity(0.15)),
                    _buildActionTile(
                      icon: Icons.shield_outlined,
                      title: "Veri Mimarisi ve Güvenlik",
                      textColor: textColor,
                      onTap: _showPrivacyPolicy,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  "Hesap",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildActionTile(
                      icon: Icons.info_outline,
                      title: "Sürüm",
                      trailingText: "1.3.0 (Hardware-Ready)",
                      textColor: textColor,
                      onTap: () {},
                    ),
                    Divider(height: 1, indent: 64, color: Colors.grey.withOpacity(0.15)),
                    _buildActionTile(
                      icon: Icons.logout,
                      title: "Çıkış Yap",
                      textColor: AppColors.statusCritical,
                      iconColor: AppColors.statusCritical,
                      iconBgColor: AppColors.statusCritical.withOpacity(0.1),
                      onTap: () async {
                        await authProvider.signOut();
                        if (context.mounted) {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required Color textColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: textColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? trailingText,
    required Color textColor,
    Color? iconColor,
    Color? iconBgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor ?? Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? textColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}