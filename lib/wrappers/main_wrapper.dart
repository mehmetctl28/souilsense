import 'package:flutter/material.dart';
import '../screens/explore_screen.dart';
import '../screens/home_screen.dart';
import '../screens/my_plants_screen.dart';
import '../constants/colors.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  // Ekran görüntülerindeki gibi varsayılan olarak ortadaki "Ana Sayfa" (index 1) açık başlar
  int _selectedIndex = 1;

  final List<Widget> _screens = const [
    ExploreScreen(),
    HomeScreen(),
    MyPlantsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        indicatorColor: AppColors.primary.withOpacity(0.15),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: AppColors.primary),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_florist_outlined),
            selectedIcon: Icon(Icons.local_florist, color: AppColors.primary),
            label: 'Bitkilerim',
          ),
        ],
      ),
    );
  }
}