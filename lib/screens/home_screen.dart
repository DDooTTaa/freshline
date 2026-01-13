import 'package:flutter/material.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  String _currentWord = '';
  String? _todayExample; // 오늘의 단어 예시 문장
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, String> _userInfo = {};
  bool _isLoadingWord = true;
  bool _isLoadingWordInProgress = false; // 중복 호출 방지
  String? _cachedDate; // 캐시된 날짜
  final PageController _pageController = PageController(initialPage: 0);
  List<Color> _gradientColors = [
    Color.fromRGBO(135, 206, 250, 1.0), // 기본 하늘색
    Color.fromRGBO(176, 224, 230, 0.5), // 기본 파란색 (연하게)
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
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
    // 디버깅: 밝기 값 출력
    print(
        '배경색: R=${backgroundColor.red}, G=${backgroundColor.green}, B=${backgroundColor.blue}');
    print('밝기(luminance): $brightness');
    print('선택된 텍스트 색상: ${brightness > 0.5 ? "검정" : "하양"}');
    // 밝기가 0.5보다 크면 검정, 작으면 하양
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
    setState(() {
      _userInfo = userInfo;
    });
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
              // 상단 네비게이션 버튼들
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
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
                        tooltip: '내 작품 모아보기',
                        color: _getTextColorForBackground(_gradientColors[0]),
                      ),
                      PopupMenuButton<String>(
                        icon: CircleAvatar(
                          radius: 16,
                          backgroundImage:
                              _userInfo['photo']?.isNotEmpty == true
                                  ? NetworkImage(_userInfo['photo']!)
                                  : null,
                          child: _userInfo['photo']?.isEmpty != false
                              ? Icon(
                                  Icons.person,
                                  size: 20,
                                  color: _getTextColorForBackground(
                                      _gradientColors[0]),
                                )
                              : null,
                        ),
                        color: Theme.of(context).colorScheme.surface,
                        onSelected: (value) async {
                          if (value == 'logout') {
                            _signOut();
                          } else if (value == 'initDailyWords') {
                            await _initializeDailyWords();
                          }
                        },
                        itemBuilder: (context) => [
                          if (_userInfo['name']?.isNotEmpty == true)
                            PopupMenuItem(
                              enabled: false,
                              child: Text(
                                _userInfo['name']!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
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
          const CommunityScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreationScreen(
                initialWord: _currentWord,
              ),
            ),
          );
        },
        child: const Icon(Icons.edit),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
