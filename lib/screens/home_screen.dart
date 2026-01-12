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
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, String> _userInfo = {};
  bool _isLoadingWord = true;
  bool _isLoadingWordInProgress = false; // 중복 호출 방지
  String? _cachedDate; // 캐시된 날짜
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
        // 단어 색상도 함께 로드
        _loadTodayWordColors();
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
        // 단어 색상도 함께 로드
        _loadTodayWordColors();
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '언어 스트레칭',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CommunityScreen(),
                ),
              );
            },
            tooltip: '커뮤니티',
          ),
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
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundImage: _userInfo['photo']?.isNotEmpty == true
                  ? NetworkImage(_userInfo['photo']!)
                  : null,
              child: _userInfo['photo']?.isEmpty != false
                  ? const Icon(Icons.person, size: 20)
                  : null,
            ),
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (_userInfo['email']?.isNotEmpty == true)
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    _userInfo['email']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _gradientColors,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const Text(
                  '언어 스트레칭',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 32,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '오늘의 단어',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _isLoadingWord
                            ? const CircularProgressIndicator()
                            : Text(
                                _currentWord,
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
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
                    icon: const Icon(Icons.edit, size: 24),
                    label: const Text(
                      '글쓰기',
                      style: TextStyle(fontSize: 20),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CommunityScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people),
                  label: const Text('커뮤니티 보기'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
