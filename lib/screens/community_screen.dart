import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _todayWord = '';
  bool _isLoadingWord = true;

  @override
  void initState() {
    super.initState();
    _loadTodayWord();
  }

  Future<void> _loadTodayWord() async {
    try {
      // daily_words에서 오늘의 단어 가져오기
      final word = await _firestoreService.getTodayWordFromDailyWords();
      setState(() {
        _todayWord = word;
        _isLoadingWord = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingWord = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티'),
      ),
      body: Column(
        children: [
          // 오늘의 단어 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              children: [
                const Text(
                  '오늘의 단어',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                _isLoadingWord
                    ? const CircularProgressIndicator()
                    : Text(
                        _todayWord,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('yyyy년 MM월 dd일').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // 공개 작품 목록
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.getTodayWordCreations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
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
                          Icons.edit_note,
                          size: 80,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '아직 공유된 작품이 없습니다',
                          style: TextStyle(
                            fontSize: 18,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '첫 번째 작품을 공유해보세요!',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
                    final hasLiked =
                        userId.isNotEmpty && likes.contains(userId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 사용자 정보
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage:
                                      creation['userPhoto']?.isNotEmpty == true
                                          ? NetworkImage(
                                              creation['userPhoto'] as String)
                                          : null,
                                  child: creation['userPhoto']?.isEmpty != false
                                      ? const Icon(Icons.person, size: 16)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        creation['userName'] as String? ?? '익명',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MM/dd HH:mm').format(
                                          creation['createdAt'] as DateTime,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 작품 내용
                            Text(
                              creation['sentence'] as String? ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 단어 정보
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
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
                                                  const TextStyle(fontSize: 12),
                                            ),
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .surfaceVariant,
                                            padding: EdgeInsets.zero,
                                          ),
                                          if (isReplaced) ...[
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 4),
                                              child: Icon(Icons.arrow_forward,
                                                  size: 16),
                                            ),
                                            Chip(
                                              label: Text(
                                                replacedWord,
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer,
                                              padding: EdgeInsets.zero,
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 좋아요 버튼
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
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
