import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 카카오 SDK 초기화 (웹/앱 모두 지원)
  if (!kIsWeb) {
    // 모바일 앱용 카카오 SDK 초기화
    KakaoSdk.init(
      nativeAppKey: '170335610a381f3d5df14fc1386bf0ae', // TODO: 실제 네이티브 앱 키로 변경
    );
  }
  // 웹용은 index.html에서 JavaScript SDK로 초기화됨

  // 인증 서비스 초기화
  await AuthService().initialize();

  runApp(const LanguageStretchingApp());
}

class LanguageStretchingApp extends StatelessWidget {
  const LanguageStretchingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Langth:시를 쓰는 시간',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // fontFamily: 'Pretendard', // 폰트 파일 추가 후 주석 해제
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await _authService.initialize();
    setState(() {
      _isSignedIn = _authService.isSignedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isSignedIn ? const HomeScreen() : const LoginScreen();
  }
}
