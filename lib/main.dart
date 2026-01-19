import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'wrappers/main_wrapper.dart';
import 'package:provider/provider.dart';
import 'providers/plant_provider.dart';
import 'providers/todo_provider.dart';
import 'screens/add_plant_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (DefaultFirebaseOptions.currentPlatform != null) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    debugPrint('Firebase init failed (will fallback to local): $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlantProvider()),
        ChangeNotifierProvider(create: (_) => TodoProvider()),
      ],
      child: MaterialApp(
        title: 'SoilSense',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1B5E20)),
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (_) => const MainWrapper(),
          '/add': (_) => const AddPlantScreen(),
        },
      ),
    );
  }
}
