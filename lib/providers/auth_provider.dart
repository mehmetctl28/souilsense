import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isLoading = true;
  StreamSubscription<User?>? _authSubscription;

  User? get currentUser => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _user = _auth.currentUser;
    _isLoading = false;
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<String?> signIn(String email, String password) async {
    try {
      final UserCredential result = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));

      _user = result.user ?? _auth.currentUser;
      _isLoading = false;
      notifyListeners();
      return null;
    } on TimeoutException {
      return "Sunucu yanıt vermedi (Zaman aşımı). İnternet bağlantınızı kontrol edin.";
    } on FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuth Hatası: ${e.code} - ${e.message}");
      return _hataMesajiCevir(e.code);
    } catch (e) {
      debugPrint("Genel Giriş Hatası: $e");
      return "Giriş hatası: $e";
    }
  }

  Future<String?> signUp(String email, String password, String userName) async {
    try {
      final UserCredential result = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));

      if (result.user != null) {
        await result.user!.updateDisplayName(userName);
        await result.user!.reload();
        _user = _auth.currentUser;
        _isLoading = false;
        notifyListeners();
      }
      return null;
    } on TimeoutException {
      return "Kayıt işlemi zaman aşımına uğradı. İnternet bağlantınızı kontrol edin.";
    } on FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuth Kayıt Hatası: ${e.code} - ${e.message}");
      return _hataMesajiCevir(e.code);
    } catch (e) {
      debugPrint("Genel Kayıt Hatası: $e");
      return "Kayıt hatası: $e";
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

  String _hataMesajiCevir(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı (Hesap bulunamadı).';
      case 'wrong-password':
        return 'Şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta zaten kullanımda.';
      case 'invalid-email':
        return 'Geçersiz e-posta formatı.';
      case 'weak-password':
        return 'Şifre çok zayıf (en az 6 karakter).';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok veya engellendi.';
      default:
        return 'Giriş başarısız ($code).';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}