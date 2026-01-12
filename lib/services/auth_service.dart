import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb ? null : '1:624224167958:web:121ae29c2bf7eead422d37',
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;

  GoogleSignInAccount? _currentUser;
  bool _isSignedIn = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _isSignedIn;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      // 웹에서는 Firebase Auth 상태 확인
      _isSignedIn = _auth.currentUser != null;
    } else {
      _isSignedIn = prefs.getBool('is_signed_in') ?? false;
      if (_isSignedIn) {
        try {
          _currentUser = await _googleSignIn.signInSilently();
          if (_currentUser == null) {
            _isSignedIn = false;
            await prefs.setBool('is_signed_in', false);
          }
        } catch (e) {
          _isSignedIn = false;
          await prefs.setBool('is_signed_in', false);
        }
      }
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // 웹에서는 Firebase Auth 직접 사용
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential =
            await _auth.signInWithPopup(googleProvider);

        if (userCredential.user != null) {
          _isSignedIn = true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_signed_in', true);
          await prefs.setString('user_email', userCredential.user!.email ?? '');
          await prefs.setString(
              'user_name', userCredential.user!.displayName ?? '');
          await prefs.setString(
              'user_photo', userCredential.user!.photoURL ?? '');
          return true;
        }
        return false;
      } else {
        // 모바일에서는 기존 방식 사용
        final GoogleSignInAccount? account = await _googleSignIn.signIn();
        if (account != null) {
          _currentUser = account;
          _isSignedIn = true;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_signed_in', true);
          await prefs.setString('user_email', account.email);
          await prefs.setString('user_name', account.displayName ?? '');
          await prefs.setString('user_photo', account.photoUrl ?? '');
          return true;
        }
        return false;
      }
    } catch (e) {
      print('구글 로그인 오류: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      if (kIsWeb) {
        await _auth.signOut();
      } else {
        await _googleSignIn.signOut();
      }

      _currentUser = null;
      _isSignedIn = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_signed_in', false);
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('user_photo');
    } catch (e) {
      print('로그아웃 오류: $e');
    }
  }

  Future<Map<String, String>> getUserInfo() async {
    if (kIsWeb && _auth.currentUser != null) {
      final user = _auth.currentUser!;
      return {
        'email': user.email ?? '',
        'name': user.displayName ?? '',
        'photo': user.photoURL ?? '',
      };
    }

    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('user_email') ?? '',
      'name': prefs.getString('user_name') ?? '',
      'photo': prefs.getString('user_photo') ?? '',
    };
  }
}
