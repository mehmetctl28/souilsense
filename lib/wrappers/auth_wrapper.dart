import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import 'main_wrapper.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // 1. Oturum durumu henüz kontrol ediliyorsa yüklenme ekranı göster
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // 2. Kullanıcı giriş yapmışsa ana ekrana, yapmamışsa giriş ekranına yönlendir
    if (authProvider.isAuthenticated) {
      return const MainWrapper();
    } else {
      return const LoginScreen();
    }
  }
}