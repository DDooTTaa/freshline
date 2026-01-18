import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class CommunityScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;

  const CommunityScreen({
    super.key,
    this.onNavigateToHome,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();
  String _todayWord = '';
  bool _showFollowingOnly = false; // 팔로우한 사용자만 보기
  final Map<String, bool> _expandedCards = {}; // 카드별 확장 상태

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTodayWord();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // StreamBuilder가 자동으로 업데이트되므로 별도 처리 불필요
  }

  Future<void> _loadTodayWord() async {
    try {
      // daily_words에서 오늘의 단어 가져오기
      final word = await _firestoreService.getTodayWordFromDailyWords();
      if (mounted) {
        setState(() {
          _todayWord = word;
        });
      }
    } catch (e) {
      // 오류 발생 시 기본값 유지
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
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
          // 글감으로 이동 버튼
          IconButton(
            icon: const Icon(Icons.edit_note),
            onPressed: widget.onNavigateToHome,
            tooltip: '글감으로 이동',
          ),
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
        stream: _showFollowingOnly
            ? _firestoreService.getFollowingCreations()
            : _firestoreService.getPublicCreations(),
        builder: (context, snapshot) {
          // StreamBuilder가 아직 데이터를 받지 않았을 때만 로딩 표시
          // 데이터가 이미 있으면 waiting 상태여도 로딩을 표시하지 않음
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
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
                        ? '팔로우한 작품이 없습니다'
                        : '공유된 작품이 없습니다',
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

              // 밝은 색상(빛 등)을 위한 최소 opacity 계산
              final baseColor = gradientColors[0];
              final brightness = baseColor.computeLuminance();
              // 밝기가 0.7 이상이면 (빛, 별 등 밝은 색상) 최소 opacity를 높임
              final minOpacity = brightness > 0.7 ? 0.25 : 0.15;

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
                        // 색 하나와 흰색만 사용
                        gradientColors[0].withOpacity(minOpacity), // 상단 색상
                        Colors.white, // 맨 아래 흰색
                      ],
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
                                // 사용자 이름 및 단어 정보
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            creation['userName'] as String? ??
                                                '익명',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (creation['originalWords'] !=
                                              null) ...[
                                            const SizedBox(width: 8),
                                            ...List.generate(
                                              (creation['originalWords']
                                                      as List)
                                                  .length,
                                              (index) {
                                                final originalWords =
                                                    creation['originalWords']
                                                        as List;
                                                final replacedWords =
                                                    creation['replacedWords']
                                                            as List? ??
                                                        originalWords;
                                                final originalWord =
                                                    originalWords[index]
                                                        as String;
                                                final replacedWord =
                                                    index < replacedWords.length
                                                        ? replacedWords[index]
                                                            as String
                                                        : originalWord;
                                                final isReplaced =
                                                    originalWord !=
                                                        replacedWord;

                                                return Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Chip(
                                                      label: Text(
                                                        originalWord,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.white,
                                                      padding: EdgeInsets.zero,
                                                    ),
                                                    if (isReplaced) ...[
                                                      const Padding(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 2),
                                                        child: Icon(
                                                          Icons.arrow_forward,
                                                          size: 12,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                      Chip(
                                                        label: Text(
                                                          replacedWord,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                        ),
                                                        backgroundColor:
                                                            Colors.white,
                                                        padding:
                                                            EdgeInsets.zero,
                                                      ),
                                                    ],
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ],
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
                            Builder(
                              builder: (context) {
                                final sentence =
                                    creation['sentence'] as String? ?? '';
                                final cardId = creation['id'] as String? ?? '';
                                final isExpanded =
                                    _expandedCards[cardId] ?? false;
                                final shouldShowMore =
                                    sentence.length > 100; // 100자 이상이면 더보기 표시
                                final previewText = sentence.length > 100
                                    ? '${sentence.substring(0, 100)}...'
                                    : sentence;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedCrossFade(
                                      firstChild: Text(
                                        previewText,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                      secondChild: Text(
                                        sentence,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                      crossFadeState:
                                          isExpanded || !shouldShowMore
                                              ? CrossFadeState.showSecond
                                              : CrossFadeState.showFirst,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      sizeCurve: Curves.easeInOut,
                                    ),
                                    if (shouldShowMore)
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _expandedCards[cardId] =
                                                !isExpanded;
                                          });
                                        },
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            isExpanded ? '접기' : '더보기',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
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
