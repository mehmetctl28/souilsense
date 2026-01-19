import 'package:flutter/material.dart';
import '../constants/text_styles.dart';
import '../constants/colors.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  final List<Map<String,String>> tips = const [
    {'title':'Sulama ipucu','subtitle':'Toprağı parmağınla kontrol et, sadece kuruduğunda su ver.'},
    {'title':'Işık ihtiyacı','subtitle':'Doğu veya batı pencere bitkileri için idealdir.'},
    {'title':'Gübreleme','subtitle':'Bahar başında hafif bir gübreleme yeterlidir.'},
    {'title':'Yaprak temizliği','subtitle':'Tozlu yaprakları nemli bezle sil.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keşfet')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tips.length,
        separatorBuilder: (_,__)=>const SizedBox(height:12),
        itemBuilder: (context, index){
          final t = tips[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  Container(width:56, height:56, decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.lightbulb, color: AppColors.accent)),
                  const SizedBox(width:12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t['title']!, style: AppTextStyles.title.copyWith(fontSize:16)),
                      const SizedBox(height:6),
                      Text(t['subtitle']!, style: AppTextStyles.body),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
