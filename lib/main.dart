import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/colors.dart';
import 'providers/auth_provider.dart';
import 'providers/plant_provider.dart';
import 'providers/todo_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/sensor_provider.dart';
import 'wrappers/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase başlatma uyarısı: $e");
  }

  // Kritik 3 & 4: Ayarları uygulama çizilmeden ÖNCE senkronize oku
  final prefs = await SharedPreferences.getInstance();
  final bool initialHardwareMode = prefs.getBool('is_hardware_mode') ?? false;
  final int initialMaxPumpSeconds = prefs.getInt('max_pump_seconds') ?? 15;
  final int initialOfflineMinutes = prefs.getInt('offline_timeout_minutes') ?? 30;

  runApp(
    MyApp(
      initialHardwareMode: initialHardwareMode,
      initialMaxPumpSeconds: initialMaxPumpSeconds,
      initialOfflineMinutes: initialOfflineMinutes,
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool initialHardwareMode;
  final int initialMaxPumpSeconds;
  final int initialOfflineMinutes;

  const MyApp({
    super.key,
    required this.initialHardwareMode,
    required this.initialMaxPumpSeconds,
    required this.initialOfflineMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlantProvider()),
        ChangeNotifierProxyProvider<PlantProvider, SensorProvider>(
          create: (_) => SensorProvider(
            initialHardwareMode: initialHardwareMode,
            initialMaxPumpSeconds: initialMaxPumpSeconds,
            initialOfflineMinutes: initialOfflineMinutes,
          ),
          update: (_, plantProvider, sensorProvider) {
            final sp = sensorProvider ??
                SensorProvider(
                  initialHardwareMode: initialHardwareMode,
                  initialMaxPumpSeconds: initialMaxPumpSeconds,
                  initialOfflineMinutes: initialOfflineMinutes,
                );
            // Kritik 1 & 2: Yalnızca kullanıcının kendi bitkilerine ait sensörleri dinle ve eşikleri senkronize et
            sp.syncAuthorizedPlants(plantProvider.plants);
            return sp;
          },
        ),
        ChangeNotifierProxyProvider2<PlantProvider, SensorProvider, TodoProvider>(
          create: (_) => TodoProvider(),
          update: (_, plantProvider, sensorProvider, todoProvider) {
            final todo = todoProvider ?? TodoProvider();
            todo.onTelemetryOrPlantsUpdated(
              plantProvider.plants,
              sensorProvider.sensors,
            );
            return todo;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'SoilSense',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              primaryColor: AppColors.primary,
              scaffoldBackgroundColor: AppColors.background,
              cardColor: Colors.white,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.light,
                surface: Colors.white,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: AppColors.primary,
              scaffoldBackgroundColor: const Color(0xFF121212),
              cardColor: const Color(0xFF1E1E1E),
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.dark,
                surface: const Color(0xFF1E1E1E),
              ),
              useMaterial3: true,
            ),
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}