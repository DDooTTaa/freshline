import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();
  String _todayWord = '';
  bool _isLoadingWord = true;
  bool _showFollowingOnly = false; // 팔로우한 사용자만 보기
  bool _isRefreshing = false; // 재렌더링 중인지 확인
  int _streamKey = 0; // StreamBuilder 재생성을 위한 key

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTodayWord();
    // 초기 로딩 상태 설정
    _isRefreshing = true;
    // StreamBuilder를 재생성하여 강제로 다시 구독
    _streamKey++;
    // StreamBuilder가 데이터를 다시 받을 때까지 로딩 표시 (최소 1.5초)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱이 다시 활성화될 때 데이터 새로고침
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _refreshData() {
    // 재렌더링 시작
    if (mounted) {
      setState(() {
        _isRefreshing = true;
        // StreamBuilder를 재생성하여 강제로 다시 구독
        _streamKey++;
      });
      // StreamBuilder가 데이터를 다시 받을 때까지 로딩 표시 (최소 1.5초)
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _isRefreshing = false;
          });
        }
      });
    }
  }

  Future<void> _loadTodayWord() async {
    try {
      // daily_words에서 오늘의 단어 가져오기
      final word = await _firestoreService.getTodayWordFromDailyWords();
      if (mounted) {
        setState(() {
          _todayWord = word;
          _isLoadingWord = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingWord = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('yyyy년 MM월 dd일').format(DateTime.now()),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            if (_todayWord.isNotEmpty) ...[
              Text(
                ',',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _todayWord,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 88, 79, 79),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon:
                Icon(_showFollowingOnly ? Icons.people : Icons.people_outline),
            onPressed: () {
              setState(() {
                _showFollowingOnly = !_showFollowingOnly;
              });
            },
            tooltip: _showFollowingOnly ? '전체 보기' : '팔로우한 사용자만 보기',
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_streamKey), // StreamBuilder 재생성을 위한 key
        stream: _showFollowingOnly
            ? _firestoreService.getFollowingCreations()
            : _firestoreService.getPublicCreations(),
        builder: (context, snapshot) {
          // 재렌더링 중이거나 초기 로딩 중일 때 로딩 표시
          // _isRefreshing이 true이면 데이터가 있어도 로딩 표시
          if (_isRefreshing) {
            return const Center(child: CircularProgressIndicator());
          }
          // StreamBuilder가 아직 데이터를 받지 않았을 때
          if (snapshot.connectionState == ConnectionState.waiting ||
              (!snapshot.hasData && !snapshot.hasError)) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('오류가 발생했습니다: ${snapshot.error}'),
            );
          }

          final creations = snapshot.data ?? [];

          if (creations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showFollowingOnly ? Icons.people_outline : Icons.edit_note,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showFollowingOnly
                        ? '팔로우한 사용자의 작품이 없습니다'
                        : '아직 공유된 작품이 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showFollowingOnly
                        ? '다른 사용자를 팔로우해보세요!'
                        : '첫 번째 작품을 공유해보세요!',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: creations.length,
            itemBuilder: (context, index) {
              final creation = creations[index];
              final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
              final likes = List<String>.from(creation['likes'] ?? []);
              final hasLiked = userId.isNotEmpty && likes.contains(userId);

              // 글감 단어 가져오기
              final word = creation['word'] as String? ?? '';
              final gradientColors = word.isNotEmpty
                  ? _firestoreService.getWordColors(word)
                  : [
                      Color.fromRGBO(135, 206, 250, 1.0), // 기본 하늘색
                      Color.fromRGBO(176, 224, 230, 1.0), // 기본 파란색
                    ];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        gradientColors[0].withOpacity(0.3), // 상단 색상
                        gradientColors.length > 1
                            ? Color.lerp(
                                gradientColors[0].withOpacity(0.3),
                                gradientColors[1].withOpacity(0.2),
                                0.5,
                              )! // 첫 번째와 두 번째 색상의 중간
                            : gradientColors[0].withOpacity(0.25),
                        gradientColors.length > 1
                            ? gradientColors[1].withOpacity(0.15) // 두 번째 색상
                            : gradientColors[0].withOpacity(0.2),
                        Color.lerp(
                          gradientColors.length > 1
                              ? gradientColors[1].withOpacity(0.15)
                              : gradientColors[0].withOpacity(0.2),
                          Colors.white,
                          0.3,
                        )!, // 색상에서 흰색으로의 중간
                        Colors.white, // 맨 아래 흰색
                      ],
                      stops: const [0.0, 0.2, 0.45, 0.7, 0.85], // 더 부드러운 전환
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 사용자 정보 및 날짜
                            Stack(
                              children: [
                                // 사용자 이름
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        creation['userName'] as String? ?? '익명',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // 날짜 (우측 상단)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Text(
                                    DateFormat('M월 d일 H:mm').format(
                                      creation['createdAt'] as DateTime,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 작품 내용
                            Padding(
                              padding: const EdgeInsets.only(bottom: 40.0),
                              child: Text(
                                creation['sentence'] as String? ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            // 좋아요 버튼 및 팔로우 버튼
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    hasLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: hasLiked ? Colors.red : null,
                                  ),
                                  onPressed: () {
                                    _firestoreService
                                        .toggleLike(creation['id'] as String);
                                  },
                                ),
                                Text(
                                  '${creation['likeCount'] ?? 0}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 8),
                                // 팔로우 버튼 (자신의 작품이 아닐 때만 표시)
                                if (creation['userId'] != userId)
                                  StreamBuilder<bool>(
                                    stream: _firestoreService.isFollowingStream(
                                        creation['userId'] as String),
                                    builder: (context, snapshot) {
                                      final isFollowing =
                                          snapshot.data ?? false;
                                      return TextButton.icon(
                                        icon: Icon(
                                          isFollowing
                                              ? Icons.person
                                              : Icons.person_add,
                                          size: 16,
                                        ),
                                        label: Text(
                                          isFollowing ? '팔로잉' : '팔로우',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () async {
                                          final success =
                                              await _firestoreService
                                                  .toggleFollow(
                                                      creation['userId']
                                                          as String);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(success
                                                    ? '팔로우했습니다'
                                                    : '언팔로우했습니다'),
                                                duration:
                                                    const Duration(seconds: 1),
                                              ),
                                            );
                                          }
                                        },
                                      );
                                    },
                                  ),
                                const Spacer(),
                              ],
                            ),
                          ],
                        ),
                        // 단어 정보 (우측 하단)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            alignment: WrapAlignment.end,
                            children: [
                              if (creation['originalWords'] != null)
                                ...List.generate(
                                  (creation['originalWords'] as List).length,
                                  (index) {
                                    final originalWords =
                                        creation['originalWords'] as List;
                                    final replacedWords =
                                        creation['replacedWords'] as List? ??
                                            originalWords;
                                    final originalWord =
                                        originalWords[index] as String;
                                    final replacedWord =
                                        index < replacedWords.length
                                            ? replacedWords[index] as String
                                            : originalWord;
                                    final isReplaced =
                                        originalWord != replacedWord;

                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Chip(
                                          label: Text(
                                            originalWord,
                                            style:
                                                const TextStyle(fontSize: 10),
                                          ),
                                          backgroundColor: Colors.white,
                                          padding: EdgeInsets.zero,
                                        ),
                                        if (isReplaced) ...[
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 2),
                                            child: Icon(Icons.arrow_forward,
                                                size: 12),
                                          ),
                                          Chip(
                                            label: Text(
                                              replacedWord,
                                              style:
                                                  const TextStyle(fontSize: 10),
                                            ),
                                            backgroundColor: Colors.white,
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
