import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'dart:math' as math;
import '../services/word_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'creation_screen.dart';
import 'gallery_screen.dart';
import 'login_screen.dart';
import 'community_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _currentWord = '';
  String? _todayExample; // 오늘의 단어 예시 문장
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, String> _userInfo = {};
  String? _userNickname; // 사용자 닉네임
  bool _isLoadingWord = true;
  bool _isLoadingWordInProgress = false; // 중복 호출 방지
  String? _cachedDate; // 캐시된 날짜
  final PageController _pageController = PageController(initialPage: 0);
  late AnimationController _arrowAnimationController;
  late AnimationController _waveAnimationController;
  int _communityScreenKey = 0; // CommunityScreen 재생성을 위한 key
  List<Color> _gradientColors = [
    Color.fromRGBO(135, 206, 250, 1.0), // 기본 하늘색
    Color.fromRGBO(176, 224, 230, 0.5), // 기본 파란색 (연하게)
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _initializeWordPoolIfNeeded();
    _loadTodayWord();
    _loadUserInfo();
    _loadTodayWordColors();
    _loadTodayWordExample();
  }

  Future<void> _loadTodayWordExample() async {
    try {
      final example = await _firestoreService.getTodayWordExample();
      if (mounted) {
        setState(() {
          _todayExample = example;
        });
      }
    } catch (e) {
      print('오늘의 단어 예시 로드 오류: $e');
    }
  }

  Future<void> _loadTodayWordColors() async {
    try {
      final colors = await _firestoreService.getTodayWordColors();
      if (mounted && colors.length >= 2) {
        setState(() {
          // 상단 색상 -> 하단 색상(연하게) -> 흰색 순서로 그라데이션 생성
          _gradientColors = [
            colors[0], // 상단 색상
            colors[1].withOpacity(0.4), // 하단 색상을 더 연하게
            Colors.white, // 흰색
          ];
        });
      }
    } catch (e) {
      print('단어 색상 로드 오류: $e');
    }
  }

  // 배경색에 따라 텍스트 색상 결정 (밝으면 검정, 어두우면 하양)
  Color _getTextColorForBackground(Color backgroundColor) {
    // 색상의 밝기 계산 (0.0 ~ 1.0)
    final brightness = backgroundColor.computeLuminance();
    // 밝기가 0.3보다 크면 검정, 작으면 하양
    return brightness > 0.3 ? Colors.black : Colors.white;
  }

  // 단어 풀이 없으면 초기화
  Future<void> _initializeWordPoolIfNeeded() async {
    try {
      // 단어 풀 초기화 (내부에서 중복 확인)
      await _firestoreService.initializeWordPool();
    } catch (e) {
      print('단어 풀 초기화 오류: $e');
    }
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await _authService.getUserInfo();
    final nickname = await _firestoreService.getUserNickname();
    setState(() {
      _userInfo = userInfo;
      _userNickname = nickname;
    });
  }

  Future<void> _showWordSelectionDialog() async {
    final words = WordService.getAllWords();

    final selectedWord = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('글감 선택'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: words.length,
            itemBuilder: (context, index) {
              final word = words[index];
              final isSelected = word == _currentWord;
              return ListTile(
                title: Text(word),
                selected: isSelected,
                onTap: () {
                  Navigator.pop(context, word);
                },
                trailing: isSelected
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );

    if (selectedWord != null && selectedWord.isNotEmpty) {
      // 선택한 단어로 오늘의 단어 변경
      setState(() {
        _currentWord = selectedWord;
        // 선택한 단어의 색상으로 즉시 업데이트
        final colors = _firestoreService.getWordColors(selectedWord);
        if (colors.length >= 2) {
          _gradientColors = [
            colors[0], // 상단 색상
            colors[1].withOpacity(0.4), // 하단 색상을 더 연하게
            Colors.white, // 흰색
          ];
        }
      });
      // 예시도 업데이트 (선택 사항)
      _loadTodayWordExample();
    }
  }

  Future<void> _showNicknameDialog() async {
    final TextEditingController nicknameController = TextEditingController();

    // 현재 닉네임 가져오기
    try {
      final profile = await _firestoreService.getUserProfile();
      if (profile != null && profile['nickname'] != null) {
        nicknameController.text = profile['nickname'] as String;
      } else if (_userInfo['name']?.isNotEmpty == true) {
        nicknameController.text = _userInfo['name']!;
      }
    } catch (e) {
      print('닉네임 조회 오류: $e');
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('닉네임 설정'),
        content: TextField(
          controller: nicknameController,
          decoration: const InputDecoration(
            hintText: '닉네임을 입력하세요',
            border: OutlineInputBorder(),
          ),
          maxLength: 20,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final nickname = nicknameController.text.trim();
              if (nickname.isNotEmpty) {
                Navigator.pop(context, nickname);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        // 닉네임 유효성 검사
        if (result.length > 20) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('닉네임은 20자 이하여야 합니다.')),
            );
          }
          return;
        }

        await _firestoreService.updateUserProfile(nickname: result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('닉네임이 저장되었습니다.')),
          );
          // 사용자 정보 다시 로드
          await _loadUserInfo();
        }
      } catch (e) {
        print('닉네임 저장 오류 상세: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('닉네임 저장 중 오류가 발생했습니다: ${e.toString()}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  }

  Future<void> _loadTodayWord() async {
    // 이미 로딩 중이면 중복 호출 방지
    if (_isLoadingWordInProgress) return;

    // 오늘 날짜 확인
    final today = _getDateString(DateTime.now());

    // 같은 날짜면 이미 로드된 단어 사용
    if (_cachedDate == today && _currentWord.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoadingWord = true;
      _isLoadingWordInProgress = true;
    });

    try {
      // daily_words에서 오늘의 단어 가져오기
      final word = await _firestoreService.getTodayWordFromDailyWords();
      if (mounted) {
        setState(() {
          _currentWord = word;
          _isLoadingWord = false;
          _isLoadingWordInProgress = false;
          _cachedDate = today;
        });
        // 단어 색상과 예시도 함께 로드
        _loadTodayWordColors();
        _loadTodayWordExample();
      }
    } catch (e) {
      print('오늘의 단어 로드 오류: $e');
      if (mounted) {
        setState(() {
          _currentWord = WordService.getRandomWords(count: 1).first;
          _isLoadingWord = false;
          _isLoadingWordInProgress = false;
          _cachedDate = today;
        });
        // 단어 색상과 예시도 함께 로드
        _loadTodayWordColors();
        _loadTodayWordExample();
      }
    }
  }

  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 날짜별 단어 초기화
  Future<void> _initializeDailyWords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('날짜별 단어 초기화'),
        content: const Text(
          '오늘부터 80일간의 날짜별 단어와 예시 문장을 설정하시겠습니까?\n\n'
          '이미 설정된 날짜는 건너뜁니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success =
          await _firestoreService.initializeDailyWordsWithExamples();

      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('날짜별 단어 초기화가 완료되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
        // 오늘의 단어 다시 로드
        _loadTodayWord();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('날짜별 단어 초기화 중 오류가 발생했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _arrowAnimationController.dispose();
    _waveAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // FloatingActionButton이 body 영역을 확장하도록
      body: PageView(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const _SensitivePageScrollPhysics(), // 민감한 스크롤 감도
        children: [
          // 첫 번째 페이지: 홈 화면
          Stack(
            children: [
              // 전체 화면 배경
              Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _gradientColors,
                  ),
                ),
              ),
              // 물결 애니메이션
              AnimatedBuilder(
                animation: _waveAnimationController,
                builder: (context, child) {
                  final t = (_waveAnimationController
                              .lastElapsedDuration?.inMilliseconds ??
                          0) /
                      1000.0;
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _HomeWavePainter(t),
                  );
                },
              ),
              // 상단 네비게이션 버튼들
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 왼쪽: 글감 선택 버튼
                      TextButton.icon(
                        onPressed: _showWordSelectionDialog,
                        icon: Icon(
                          Icons.edit_note,
                          color: _getTextColorForBackground(_gradientColors[0]),
                        ),
                        label: Text(
                          '글감 선택',
                          style: TextStyle(
                            color:
                                _getTextColorForBackground(_gradientColors[0]),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // 오른쪽: 갤러리 및 프로필 버튼
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.collections_bookmark),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const GalleryScreen(),
                                ),
                              );
                            },
                            tooltip: '내 글',
                            color:
                                _getTextColorForBackground(_gradientColors[0]),
                          ),
                          PopupMenuButton<String>(
                            icon: CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              child: const Text(
                                '👤',
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                            color: Theme.of(context).colorScheme.surface,
                            onSelected: (value) async {
                              if (value == 'logout') {
                                _signOut();
                              } else if (value == 'initDailyWords') {
                                await _initializeDailyWords();
                              } else if (value == 'setNickname') {
                                await _showNicknameDialog();
                              }
                            },
                            itemBuilder: (context) => [
                              if (_userNickname != null &&
                                  _userNickname!.isNotEmpty)
                                PopupMenuItem(
                                  value: 'setNickname',
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _userNickname!,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.edit, size: 16),
                                    ],
                                  ),
                                )
                              else if (_userInfo['name']?.isNotEmpty == true)
                                PopupMenuItem(
                                  value: 'setNickname',
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _userInfo['name']!,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.edit, size: 16),
                                    ],
                                  ),
                                ),
                              if (_userInfo['email']?.isNotEmpty == true)
                                PopupMenuItem(
                                  enabled: false,
                                  child: Text(
                                    _userInfo['email']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'initDailyWords',
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 20),
                                    SizedBox(width: 8),
                                    Text('날짜별 단어 초기화'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(Icons.logout, size: 20),
                                    SizedBox(width: 8),
                                    Text('로그아웃'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // 콘텐츠
              SafeArea(
                bottom: false, // 하단 SafeArea 비활성화하여 플로팅 버튼 영역까지 배경 표시
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 24.0,
                      left: 24.0,
                      right: 24.0,
                      bottom: 100.0, // 플로팅 버튼 공간 확보
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        // 글감 (오늘의 단어)
                        if (_isLoadingWord)
                          CircularProgressIndicator(
                            color:
                                _getTextColorForBackground(_gradientColors[0]),
                          )
                        else if (_currentWord.isNotEmpty)
                          Text(
                            _currentWord,
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: _getTextColorForBackground(
                                  _gradientColors[0]),
                            ),
                          ),
                        const SizedBox(height: 32),
                        // 예시 문장
                        if (_todayExample != null && _todayExample!.isNotEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Text(
                              _todayExample!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                height: 1.6,
                                color: _getTextColorForBackground(
                                        _gradientColors[0])
                                    .withOpacity(0.7), // 투명도 적용
                              ),
                            ),
                          ),
                        const Spacer(),
                        // 아래로 스크롤 화살표
                        GestureDetector(
                          onTap: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: AnimatedBuilder(
                            animation: _arrowAnimationController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                  0,
                                  math.sin(_arrowAnimationController.value *
                                          2 *
                                          math.pi) *
                                      8, // 위아래로 8픽셀 움직임
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 40,
                                      color: _getTextColorForBackground(
                                              _gradientColors[0])
                                          .withOpacity(0.5),
                                    ),
                                    Text(
                                      '아래로 스크롤',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _getTextColorForBackground(
                                                _gradientColors[0])
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 두 번째 페이지: 커뮤니티 화면
          CommunityScreen(
            key: ValueKey(_communityScreenKey),
            onNavigateToHome: () {
              if (_pageController.hasClients) {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreationScreen(
                initialWord: _currentWord,
              ),
            ),
          );
          // 커뮤니티 화면으로 이동 (StreamBuilder가 자동으로 새 데이터를 가져옴)
          if (mounted && _pageController.hasClients) {
            _pageController.animateToPage(
              1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: const Icon(Icons.edit),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// 민감한 스크롤 감도를 위한 커스텀 ScrollPhysics
class _SensitivePageScrollPhysics extends PageScrollPhysics {
  const _SensitivePageScrollPhysics({ScrollPhysics? parent})
      : super(parent: parent);

  @override
  _SensitivePageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SensitivePageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 50.0; // 기본값보다 낮춰서 작은 스크롤에도 반응

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.5, // 더 가벼운 질량으로 빠른 반응
        stiffness: 200.0,
        damping: 0.8,
      );
}

// 홈 화면용 물결 효과를 그리는 CustomPainter
class _HomeWavePainter extends CustomPainter {
  final double t;

  _HomeWavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // 4개의 실 같은 선 그리기
    for (int i = 0; i < 4; i++) {
      // 각 선마다 다른 속도와 방향
      final speed = 0.05 + (i * 0.05);
      final waveOffset = t * speed * 2 * math.pi + (i * math.pi / 6);
      final amplitude = 15.0 + (i * 5.0);
      final frequency = 0.01 + (i * 0.002);
      // 중앙보다 50px 위에 배치 (화면 중앙 기준으로 위아래로 분산)
      final centerY = size.height * 0.5 - 30;
      final spacing = 30.0; // 간격을 30으로 설정
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
  bool shouldRepaint(_HomeWavePainter oldDelegate) {
    return oldDelegate.t != t;
  }
}
