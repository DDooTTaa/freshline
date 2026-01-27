import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/creation.dart';
import '../services/firestore_service.dart';
import 'creation_detail_screen.dart';
import 'creation_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Creation> _creations = [];
  bool _isLoading = true;
  final Map<String, bool> _expandedCards = {}; // 카드별 확장 상태

  @override
  void initState() {
    super.initState();
    _loadCreations();
  }

  Future<void> _loadCreations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final creations = await _firestoreService.getCreations();
      setState(() {
        _creations = creations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('글을 불러오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _deleteCreation(Creation creation) async {
    if (creation.docId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _firestoreService.deleteCreation(creation.docId!);
        if (success) {
          _loadCreations();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('글이 삭제되었습니다.')),
            );
          }
        } else {
          throw Exception('삭제에 실패했습니다.');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('내 글'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _creations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 80,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '저장된 글이 없습니다',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCreations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _creations.length,
                    itemBuilder: (context, index) {
                      final creation = _creations[index];
                      
                      // 글감 단어 가져오기 (originalWords의 첫 번째 단어 사용)
                      final word = creation.originalWords.isNotEmpty
                          ? creation.originalWords[0]
                          : '';
                      final gradientColors = word.isNotEmpty
                          ? _firestoreService.getWordColors(word)
                          : [
                              Color.fromRGBO(135, 206, 250, 1.0), // 기본 하늘색
                              Color.fromRGBO(176, 224, 230, 1.0), // 기본 파란색
                            ];
                      
                      // 밝은 색상(빛 등)을 위한 최소 opacity 계산
                      final baseColor = gradientColors[0];
                      final brightness = baseColor.computeLuminance();
                      final minOpacity = brightness > 0.7 ? 0.25 : 0.15;
                      
                      final cardId = creation.docId ?? creation.id?.toString() ?? index.toString();
                      final isExpanded = _expandedCards[cardId] ?? false;
                      final shouldShowMore = creation.sentence.length > 100;
                      final previewText = creation.sentence.length > 100
                          ? '${creation.sentence.substring(0, 100)}...'
                          : creation.sentence;
                      
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
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CreationDetailScreen(creation: creation),
                                ),
                              ).then((_) => _loadCreations());
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 날짜 (우측 상단)
                                      Stack(
                                        children: [
                                          // 단어 정보 (왼쪽 상단)
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    if (creation.originalWords.isNotEmpty) ...[
                                                      ...List.generate(
                                                        creation.originalWords.length,
                                                        (wordIndex) {
                                                          final originalWord =
                                                              creation.originalWords[wordIndex];
                                                          final replacedWord =
                                                              wordIndex < creation.replacedWords.length
                                                                  ? creation.replacedWords[wordIndex]
                                                                  : originalWord;
                                                          final isReplaced =
                                                              originalWord != replacedWord;

                                                          return Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Chip(
                                                                label: Text(
                                                                  originalWord,
                                                                  style: const TextStyle(
                                                                    fontSize: 10,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: Colors.black87,
                                                                  ),
                                                                ),
                                                                backgroundColor: Colors.white,
                                                                padding: EdgeInsets.zero,
                                                              ),
                                                              if (isReplaced) ...[
                                                                const Padding(
                                                                  padding: EdgeInsets.symmetric(
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
                                                                    style: const TextStyle(
                                                                      fontSize: 10,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: Colors.black87,
                                                                    ),
                                                                  ),
                                                                  backgroundColor: Colors.white,
                                                                  padding: EdgeInsets.zero,
                                                                ),
                                                              ],
                                                              if (wordIndex < creation.originalWords.length - 1)
                                                                const SizedBox(width: 4),
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
                                              DateFormat('M월 d일 H:mm')
                                                  .format(creation.createdAt),
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
                                      // 글 내용
                                      Builder(
                                        builder: (context) {
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
                                                  creation.sentence,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    height: 1.5,
                                                  ),
                                                ),
                                                crossFadeState: isExpanded || !shouldShowMore
                                                    ? CrossFadeState.showSecond
                                                    : CrossFadeState.showFirst,
                                                duration: const Duration(milliseconds: 200),
                                                sizeCurve: Curves.easeInOut,
                                              ),
                                              if (shouldShowMore)
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _expandedCards[cardId] = !isExpanded;
                                                    });
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(top: 4.0),
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
                                      const SizedBox(height: 12),
                                      // 삭제 버튼
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20),
                                            onPressed: () => _deleteCreation(creation),
                                            color: Theme.of(context).colorScheme.error,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreationScreen(),
            ),
          );
          // 글쓰기 화면에서 돌아올 때 목록 새로고침
          _loadCreations();
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: const Icon(Icons.edit),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
