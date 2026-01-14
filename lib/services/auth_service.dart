import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

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

  Future<bool> signInWithKakao() async {
    try {
      if (kIsWeb) {
        // 웹에서는 Firebase Auth의 OAuthProvider 사용
        // Firebase Console에서 Kakao 제공업체를 활성화하고 설정해야 함
        // 웹에서는 카카오 JavaScript SDK를 사용해야 하므로
        // 일단 모바일 방식으로 처리하거나, 웹용 카카오 SDK 사용 필요
        // 현재는 모바일 방식으로 통일
        return false; // 웹 지원은 추후 구현
      } else {
        // 모바일에서는 카카오 SDK 사용
        // 카카오톡으로 로그인 시도
        kakao.OAuthToken token;
        final isKakaoTalkInstalled = await kakao.isKakaoTalkInstalled();

        if (isKakaoTalkInstalled) {
          // 카카오톡이 설치되어 있으면 카카오톡으로 로그인
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } else {
          // 카카오톡이 없으면 카카오계정으로 로그인
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }

        // 사용자 정보 가져오기
        kakao.User kakaoUser = await kakao.UserApi.instance.me();

        if (kakaoUser.id != null) {
          // Firebase Auth에 카카오 로그인 연동
          try {
            // 카카오 액세스 토큰을 사용하여 Firebase에 로그인
            final credential = OAuthProvider("oidc.kakao").credential(
              idToken: token.idToken,
              accessToken: token.accessToken,
            );

            final userCredential = await _auth.signInWithCredential(credential);

            if (userCredential.user != null) {
              _isSignedIn = true;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_signed_in', true);

              // 카카오에서 받은 사용자 정보 사용
              final email = kakaoUser.kakaoAccount?.email ??
                  userCredential.user!.email ??
                  '';
              final name = kakaoUser.kakaoAccount?.profile?.nickname ??
                  userCredential.user!.displayName ??
                  '';
              final photo = kakaoUser.kakaoAccount?.profile?.profileImageUrl ??
                  userCredential.user!.photoURL ??
                  '';

              await prefs.setString('user_email', email);
              await prefs.setString('user_name', name);
              await prefs.setString('user_photo', photo);

              // Firestore에 사용자 정보 저장
              try {
                final firestoreService = FirestoreService();
                await firestoreService.updateUserProfile(
                  nickname: name.isNotEmpty ? name : null,
                  photoUrl: photo.isNotEmpty ? photo : null,
                );
              } catch (e) {
                print('Firestore 사용자 정보 저장 오류: $e');
                // 오류가 발생해도 로그인은 성공한 것으로 처리
              }

              return true;
            }
          } catch (firebaseError) {
            print('Firebase 연동 오류: $firebaseError');
            // Firebase 연동 실패 시에도 카카오 로그인은 성공한 것으로 처리
            // 하지만 Firebase 기능(예: Firestore)은 사용할 수 없음
            _isSignedIn = true;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_signed_in', true);

            final email = kakaoUser.kakaoAccount?.email ?? '';
            final name = kakaoUser.kakaoAccount?.profile?.nickname ?? '';
            final photo =
                kakaoUser.kakaoAccount?.profile?.profileImageUrl ?? '';

            await prefs.setString('user_email', email);
            await prefs.setString('user_name', name);
            await prefs.setString('user_photo', photo);

            // Firebase 연동이 실패했으므로 Firestore 저장은 시도하지 않음
            print('Firebase 연동 실패로 인해 Firestore 저장을 건너뜁니다.');

            return true;
          }
        }
        return false;
      }
    } catch (e) {
      print('카카오 로그인 오류: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      if (kIsWeb) {
        await _auth.signOut();
      } else {
        await _googleSignIn.signOut();
        // 카카오 로그아웃
        try {
          await kakao.UserApi.instance.unlink();
        } catch (e) {
          print('카카오 로그아웃 오류: $e');
        }
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
