import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  late AnimationController _gradientController;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authService.signInWithGoogle();
      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인에 실패했습니다. 다시 시도해주세요.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithKakao() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authService.signInWithKakao();
      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인에 실패했습니다. 다시 시도해주세요.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, child) {
          final t =
              (_gradientController.lastElapsedDuration?.inMilliseconds ?? 0) /
                  1000.0;

          return Stack(
            children: [
              // 로고 이미지 (배경)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/Langth.png',
                      height: 350,
                      width: 350,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 0),
                    const Text(
                      '진부하지 않은 문장 만들기',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // 중앙이 흰색인 보라색 원형 그라데이션 (은은하게)
              Center(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.purple.withOpacity(0.08),
                        Colors.purple.withOpacity(0.12),
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              // 물결 배경 (이미지 위로 지나감)
              CustomPaint(
                size: Size.infinite,
                painter: WavePainter(t),
              ),
              // 콘텐츠
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 카카오 로그인 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _signInWithKakao,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'K',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                          label: Text(
                            _isLoading ? '로그인 중...' : '카카오로 로그인',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 2,
                            side:
                                const BorderSide(color: Colors.black, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 구글 로그인 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'G',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                          label: Text(
                            _isLoading ? '로그인 중...' : '구글로 로그인',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 2,
                            side:
                                const BorderSide(color: Colors.black, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// 실 같은 물결 효과를 그리는 CustomPainter
class WavePainter extends CustomPainter {
  final double t;

  WavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // 여러 개의 실 같은 선 그리기 (4개로 줄임)
    for (int i = 0; i < 4; i++) {
      // 각 선마다 다른 속도와 방향
      final speed = 0.05 + (i * 0.05);
      final waveOffset = t * speed * 2 * math.pi + (i * math.pi / 6);
      final amplitude = 15.0 + (i * 5.0);
      final frequency = 0.01 + (i * 0.002);
      // 중앙보다 50px 위에 배치 (화면 중앙 기준으로 위아래로 분산)
      final centerY = size.height * 0.5 - 30;
      final spacing = 40.0;
      final yOffset = centerY - (spacing * 1.5) + (i * spacing);

      // 실 같은 얇은 선으로 그리기
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;

      // 각 선마다 다른 색상 톤 적용
      final gradientProgress = (yOffset / size.height).clamp(0.0, 1.0);
      final baseGrayValue = (255 * gradientProgress).round();

      // 각 선마다 다른 색상 변형 적용
      int r, g, b;
      switch (i % 4) {
        case 0: // 첫 번째 선: 약간 파란색 톤
          r = ((baseGrayValue * 0.9).round()).clamp(0, 255);
          g = ((baseGrayValue * 0.95).round()).clamp(0, 255);
          b = baseGrayValue.clamp(0, 255);
          break;
        case 1: // 두 번째 선: 약간 보라색 톤
          r = ((baseGrayValue * 0.95).round()).clamp(0, 255);
          g = ((baseGrayValue * 0.9).round()).clamp(0, 255);
          b = baseGrayValue.clamp(0, 255);
          break;
        case 2: // 세 번째 선: 약간 녹색 톤
          r = ((baseGrayValue * 0.95).round()).clamp(0, 255);
          g = baseGrayValue.clamp(0, 255);
          b = ((baseGrayValue * 0.9).round()).clamp(0, 255);
          break;
        default: // 네 번째 선: 순수 회색
          r = baseGrayValue.clamp(0, 255);
          g = baseGrayValue.clamp(0, 255);
          b = baseGrayValue.clamp(0, 255);
      }

      final baseOpacity = 0.4 - (i * 0.03);

      // 선을 여러 구간으로 나누어 페이드 효과 적용
      final segmentWidth = size.width / 20; // 20개 구간으로 나눔

      for (int segment = 0; segment < 20; segment++) {
        final startX = segment * segmentWidth;
        final endX = (segment + 1) * segmentWidth;

        // 양 끝에서 페이드 인/아웃 효과
        double fadeOpacity = 1.0;
        if (segment < 3) {
          // 왼쪽 끝: 페이드 인
          fadeOpacity = segment / 3.0;
        } else if (segment > 16) {
          // 오른쪽 끝: 페이드 아웃
          fadeOpacity = (20 - segment) / 3.0;
        }

        final path = Path();
        bool isFirstPoint = true;

        // 각 구간의 곡선 생성
        for (double x = startX; x <= endX; x += 1) {
          final y = yOffset +
              amplitude *
                  math.sin((x * frequency) + waveOffset) *
                  (1.0 - (x / size.width) * 0.5);

          if (isFirstPoint) {
            path.moveTo(x, y);
            isFirstPoint = false;
          } else {
            path.lineTo(x, y);
          }
        }

        // 각 구간마다 다른 투명도 적용
        paint.color =
            Color.fromRGBO(r, g, b, baseOpacity * fadeOpacity.clamp(0.0, 1.0));

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.t != t;
  }
}
