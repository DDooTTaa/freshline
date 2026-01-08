import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  GoogleSignInAccount? _currentUser;
  bool _isSignedIn = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _isSignedIn;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
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

  Future<bool> signInWithGoogle() async {
    try {
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
    } catch (e) {
      print('구글 로그인 오류: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
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
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('user_email') ?? '',
      'name': prefs.getString('user_name') ?? '',
      'photo': prefs.getString('user_photo') ?? '',
    };
  }
}
