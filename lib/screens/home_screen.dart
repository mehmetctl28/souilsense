import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plant_provider.dart';
import '../providers/todo_provider.dart';
import '../widgets/plant_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/todo_list.dart';
import '../constants/colors.dart';
import '../constants/text_styles.dart';
import 'add_plant_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final plantProvider = Provider.of<PlantProvider>(context, listen:false);
      final todoProvider = Provider.of<TodoProvider>(context, listen:false);
      plantProvider.loadFromFirebase();
      todoProvider.loadFromFirebase();
      _initialized = true;
    }
  }

  Color _statusColor(double m) {
    if (m >= 60) return Colors.green;
    if (m >= 30) return Colors.orange;
    return Colors.red;
  }

  String _statusText(double m) {
    if (m >= 60) return 'İyi';
    if (m >= 30) return 'Orta';
    return 'Düşük';
  }

  void _openAddPlant() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlantScreen()));
  }

  void _openAddTodo() {
    final todoProvider = Provider.of<TodoProvider>(context, listen:false);
    showDialog(context: context, builder: (context){
      final c = TextEditingController();
      return AlertDialog(
        title: const Text('Yeni görev ekle'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Görev')),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(onPressed: (){
            final text = c.text.trim();
            if (text.isNotEmpty) {
              todoProvider.addTodo(text);
            }
            Navigator.pop(context);
          }, child: const Text('Ekle')),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final plantProvider = Provider.of<PlantProvider>(context);
    final todoProvider = Provider.of<TodoProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('SoilSense')),
      body: RefreshIndicator(
        onRefresh: () async {
          await plantProvider.loadFromFirebase();
          await todoProvider.loadFromFirebase();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bitki Sağlığı - horizontal
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Bitki Sağlığı', style: AppTextStyles.title),
              TextButton.icon(onPressed: _openAddPlant, icon: const Icon(Icons.add), label: const Text('Yeni')),
            ]),
            const SizedBox(height:8),
            SizedBox(
              height: 230,
              child: plantProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: plantProvider.plants.length,
                separatorBuilder: (_,__)=>const SizedBox(width:12),
                itemBuilder: (context, index){
                  final p = plantProvider.plants[index];
                  return SizedBox(
                    width: 220,
                    child: PlantCard(
                      plantName: p.name,
                      humidity: '${p.moistureLevel.toStringAsFixed(1)}%',
                      status: _statusText(p.moistureLevel),
                      statusColor: _statusColor(p.moistureLevel),
                      moistureLevel: p.moistureLevel,
                      sensorId: p.sensorId,
                      onSensorTap: ()=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sensör ${p.sensorId ?? ''}'))),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height:20),

            // Hızlı işlemler
            Text('Hızlı İşlemler', style: AppTextStyles.title),
            const SizedBox(height:8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                QuickActionButton(icon: Icons.add, label: 'Bitki Ekle', onPressed: _openAddPlant),
                QuickActionButton(icon: Icons.notifications, label: 'Hatırlatma', onPressed: (){}),
                QuickActionButton(icon: Icons.menu_book, label: 'Sözlük', onPressed: (){}),
                QuickActionButton(icon: Icons.bar_chart, label: 'İstatistik', onPressed: (){}),
              ],
            ),

            const SizedBox(height:20),

            // Yapılacaklar (güzel kart listesi)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Yapılacaklar', style: AppTextStyles.title),
              TextButton(onPressed: _openAddTodo, child: const Text('Yeni görev')),
            ]),
            const SizedBox(height:8),
            ...todoProvider.todos.map((t){
              return Dismissible(
                key: ValueKey(t.id),
                background: Container(color: Colors.green, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left:20), child: const Icon(Icons.check, color: Colors.white)),
                secondaryBackground: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right:20), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (dir){
                  if (dir == DismissDirection.startToEnd) {
                    todoProvider.toggleTodo(t.id);
                  } else {
                    todoProvider.removeTodo(t.id);
                  }
                },
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Checkbox(value: t.completed, onChanged: (_)=>todoProvider.toggleTodo(t.id)),
                    title: Text(t.task, style: TextStyle(decoration: t.completed?TextDecoration.lineThrough:null)),
                    subtitle: t.completed ? const Text('Tamamlandı') : null,
                    trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: (){}),
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height:80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTodo,
        child: const Icon(Icons.add),
      ),
    );
  }
}