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
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _hataMesajiCevir(e.code);
    } catch (e) {
      return "Giriş sırasında bir hata oluştu.";
    }
  }

  Future<String?> signUp(String email, String password, String userName) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        await result.user!.updateDisplayName(userName);
        await result.user!.reload();
        _user = _auth.currentUser;
        notifyListeners();
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _hataMesajiCevir(e.code);
    } catch (e) {
      return "Kayıt sırasında bir hata oluştu: $e";
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _hataMesajiCevir(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'wrong-password':
        return 'Şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta zaten kullanımda.';
      case 'invalid-email':
        return 'Geçersiz e-posta formatı.';
      case 'weak-password':
        return 'Şifre çok zayıf (en az 6 karakter).';
      default:
        return 'İşlem başarısız ($code). Lütfen tekrar deneyin.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}