import 'package:flutter/material.dart';
import '../constants/text_styles.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profil'),
              subtitle: const Text('Kullanıcı profili ve bilgiler'),
              onTap: (){},
            ),
          ),
          const SizedBox(height:12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              title: const Text('Koyu tema'),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (v){ /* implement theme toggle if desired */ },
            ),
          ),
          const SizedBox(height:12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Çıkış Yap'),
              onTap: (){},
            ),
          ),
        ],
      ),
    );
  }
}
