import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _notificationsEnabled = true;
  String _selectedLanguage = "Türkçe";
  int _maxPumpSeconds = 15;
  int _offlineMinutes = 30;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _selectedLanguage = prefs.getString('app_language') ?? "Türkçe";
      _maxPumpSeconds = prefs.getInt('max_pump_seconds') ?? 15;
      _offlineMinutes = prefs.getInt('offline_timeout_minutes') ?? 30;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (!mounted) return;
    setState(() => _notificationsEnabled = value);
  }

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
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
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
        int tempPump = _maxPumpSeconds;
        int tempOffline = _offlineMinutes;
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
                          await prefs.setInt('max_pump_seconds', tempPump);
                          await prefs.setInt('offline_timeout_minutes', tempOffline);
                          if (mounted) {
                            setState(() {
                              _maxPumpSeconds = tempPump;
                              _offlineMinutes = tempOffline;
                            });
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
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
        title: Text("Gizlilik ve Veri Güvenliği", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: const Text(
          "SoilSense, bitki kayıtlarınızı ve görevlerinizi yalnızca kendi kullanıcı kimliğiniz (users/UID) altında izole olarak saklar.\n\n"
          "Donanım modunda ESP32 sensör verileri üzerine uygulama tarafından simülasyon verisi yazılmaz.",
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
              // ÜST PROFİL KARTI
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
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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

              // GENEL AYARLAR
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text("Genel", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Container(
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.notifications_none,
                      title: "Bildirimler",
                      subtitle: "Kritik nem ve çevrimdışı sensör uyarıları",
                      value: _notificationsEnabled,
                      textColor: textColor,
                      onChanged: _toggleNotifications,
                    ),
                    Divider(height: 1, indent: 64, color: Colors.grey.withOpacity(0.15)),
                    _buildSwitchTile(
                      icon: Icons.dark_mode_outlined,
                      title: "Karanlık Mod",
                      subtitle: "Tercihiniz cihazda kalıcı olarak saklanır",
                      value: themeProvider.isDarkMode,
                      textColor: textColor,
                      onChanged: (val) => themeProvider.toggleTheme(val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // DONANIM VE ÇALIŞMA MODU (Bölüm 2.A)
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text("Donanım & Çalışma Modu", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Container(
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
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
                      title: "Pompa ve Sensör Sınırları",
                      trailingText: "${_maxPumpSeconds}sn / ${_offlineMinutes}dk",
                      textColor: textColor,
                      onTap: _showSensorAndPumpSettings,
                    ),
                    Divider(height: 1, indent: 64, color: Colors.grey.withOpacity(0.15)),
                    _buildActionTile(
                      icon: Icons.language,
                      title: "Dil",
                      trailingText: _selectedLanguage,
                      textColor: textColor,
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final nextLang = _selectedLanguage == "Türkçe" ? "English" : "Türkçe";
                        await prefs.setString('app_language', nextLang);
                        if (mounted) setState(() => _selectedLanguage = nextLang);
                      },
                    ),
                    Divider(height: 1, indent: 64, color: Colors.grey.withOpacity(0.15)),
                    _buildActionTile(
                      icon: Icons.lock_outline,
                      title: "Gizlilik Politikası",
                      textColor: textColor,
                      onTap: _showPrivacyPolicy,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // HESAP
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text("Hesap", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Container(
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    _buildActionTile(
                      icon: Icons.info_outline,
                      title: "Sürüm",
                      trailingText: "1.2.0 (Dual-Mode IoT)",
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
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
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
              child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
            ),
            if (trailingText != null) ...[
              Text(trailingText, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}