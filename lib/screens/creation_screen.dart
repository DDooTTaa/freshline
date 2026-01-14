import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/creation.dart';
import '../services/word_service.dart';
import '../services/firestore_service.dart';
import 'gallery_screen.dart';

class CreationScreen extends StatefulWidget {
  final String? initialWord;

  const CreationScreen({
    super.key,
    this.initialWord,
  });

  @override
  State<CreationScreen> createState() => _CreationScreenState();
}

class _CreationScreenState extends State<CreationScreen> {
  List<String> _originalWords = [];
  List<String> _replacedWords = [];
  String _sentence = '';
  final TextEditingController _sentenceController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  bool _shareToCommunity = false; // 커뮤니티 공유 여부
  // 각 위치별로 어떤 단어로 바뀌었는지 추적 (위치 -> 새 단어)
  final Map<int, String> _positionReplacements = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialWord != null && widget.initialWord!.isNotEmpty) {
      setState(() {
        _originalWords = [widget.initialWord!];
        _replacedWords = [widget.initialWord!];
        _positionReplacements.clear();
      });
    } else {
      _loadRandomWords();
    }
  }

  void _loadRandomWords() {
    setState(() {
      _originalWords = WordService.getRandomWords(count: 1);
      _replacedWords = List<String>.from(_originalWords);
      _positionReplacements.clear(); // 위치별 교체 정보 초기화
    });
  }

  void _replaceWord(int index) {
    if (_originalWords.isEmpty) return;

    final originalWord = _originalWords[index]; // 글감 단어
    final synonyms = WordService.getSynonyms(originalWord);

    // 문장이 비어있으면 안내 메시지 표시
    if (_sentence.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('먼저 문장을 작성해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 문장에서 글감 단어의 모든 위치 찾기 (이미 바뀐 위치 포함)
    // 먼저 원래 단어를 찾고, 없으면 이미 바뀐 단어를 찾기
    List<int> wordPositions = _findWordPositionsInCurrentSentence(originalWord);

    // 원래 단어가 없으면 이미 바뀐 단어를 찾기
    if (wordPositions.isEmpty) {
      // _positionReplacements에서 현재 사용 중인 단어 찾기
      final replacedWord = _replacedWords[index];
      if (replacedWord != originalWord) {
        wordPositions = _findWordPositionsInCurrentSentence(replacedWord);
      }
    }

    if (wordPositions.length > 1) {
      // 여러 개가 있으면 위치 선택 다이얼로그 표시 (복수 선택 가능)
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _WordPositionSelectionBottomSheet(
          word: originalWord,
          sentence: _sentence,
          positions: wordPositions,
          onPositionsSelected: (selectedIndices) {
            if (selectedIndices.isEmpty) {
              Navigator.pop(context);
              return;
            }

            // 선택한 위치들의 단어 확인
            final selectedPositions =
                selectedIndices.map((i) => wordPositions[i]).toList();
            final firstPosition = selectedPositions[0];
            final wordAtPosition = _sentence.substring(
              firstPosition,
              firstPosition + originalWord.length,
            );
            final currentWordAtPosition =
                _positionReplacements[firstPosition] ?? wordAtPosition;

            // 위치 선택 바텀 시트를 닫고
            Navigator.pop(context);

            // 약간의 딜레이 후 단어 바꾸기 바텀 시트 표시
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _showWordReplacementBottomSheet(
                  currentWord: currentWordAtPosition,
                  synonyms: synonyms,
                  onReplace: (newWord) {
                    if (!mounted) return;

                    // 뒤에서부터 교체하여 위치 변경 문제 방지
                    final sortedPositions = List<int>.from(selectedPositions)
                      ..sort((a, b) => b.compareTo(a));

                    // 상태 업데이트를 직접 수행 (setState 없이)
                    for (final position in sortedPositions) {
                      _updateSentenceAtPosition(
                          originalWord, newWord, position);
                    }

                    // _replacedWords 업데이트 (원래 단어가 바뀐 경우)
                    if (_originalWords.isNotEmpty &&
                        _originalWords[0] == originalWord) {
                      _replacedWords[0] = newWord;
                    }

                    // 프레임이 완료된 후에만 setState 호출하여 UI 업데이트
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          // 상태가 이미 업데이트되었으므로 빈 setState로 리빌드만 트리거
                        });
                      }
                    });
                  },
                );
              }
            });
          },
        ),
      );
    } else if (wordPositions.length == 1) {
      // 하나만 있으면 바로 단어 바꾸기 바텀 시트 표시
      final position = wordPositions[0];
      // 현재 해당 위치에 있는 단어 확인 (이미 바뀐 단어일 수 있음)
      final currentLength =
          _positionReplacements[position]?.length ?? originalWord.length;
      final wordAtPosition = _sentence.substring(
        position,
        position + currentLength,
      );
      final currentWordAtPosition =
          _positionReplacements[position] ?? wordAtPosition;

      _showWordReplacementBottomSheet(
        currentWord: currentWordAtPosition,
        synonyms: synonyms,
        onReplace: (newWord) {
          // 상태 업데이트를 직접 수행
          _updateSentenceAtPosition(originalWord, newWord, position);

          // _replacedWords 업데이트 (원래 단어가 바뀐 경우)
          if (_originalWords.isNotEmpty && _originalWords[0] == originalWord) {
            _replacedWords[0] = newWord;
          }

          // 프레임이 완료된 후에만 setState 호출하여 UI 업데이트
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                // 상태가 이미 업데이트되었으므로 빈 setState로 리빌드만 트리거
              });
            }
          });
        },
      );
    } else {
      // 문장에 글감 단어가 없으면 안내 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('문장에 "${originalWord}" 단어가 없습니다.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  List<int> _findWordPositionsInCurrentSentence(String word) {
    // 현재 문장에서 해당 단어의 위치를 찾되, 조사가 붙은 경우도 포함
    List<int> positions = [];
    int index = 0;
    final currentSentence = _sentence;

    // 한국어 조사 목록
    final koreanParticles = [
      '이',
      '가',
      '을',
      '를',
      '의',
      '에',
      '에서',
      '로',
      '으로',
      '와',
      '과',
      '도',
      '만',
      '부터',
      '까지',
      '처럼',
      '같이',
      '아',
      '야'
    ];

    while (index < currentSentence.length) {
      final foundIndex = currentSentence.indexOf(word, index);
      if (foundIndex == -1) break;

      // 단어 앞 경계 확인
      final beforeChar = foundIndex > 0 ? currentSentence[foundIndex - 1] : ' ';
      final afterIndex = foundIndex + word.length;

      // 단어 뒤에 조사가 있는지 확인
      bool hasParticle = false;
      int wordEndIndex = afterIndex;

      if (afterIndex < currentSentence.length) {
        for (final particle in koreanParticles) {
          if (currentSentence.length >= afterIndex + particle.length) {
            final possibleParticle = currentSentence.substring(
                afterIndex, afterIndex + particle.length);
            if (possibleParticle == particle) {
              // 조사 뒤에 경계 문자가 있는지 확인
              final afterParticleIndex = afterIndex + particle.length;
              if (afterParticleIndex >= currentSentence.length ||
                  _isWordBoundary(currentSentence[afterParticleIndex])) {
                hasParticle = true;
                wordEndIndex = afterParticleIndex;
                break;
              }
            }
          }
        }
      }

      // 단어 경계 확인 (앞은 경계 문자, 뒤는 경계 문자 또는 조사)
      final afterChar = wordEndIndex < currentSentence.length
          ? currentSentence[wordEndIndex]
          : ' ';

      // 연속된 단어도 각각 인식하기 위해 단어 뒤에 같은 단어가 오는 경우도 경계로 인식
      bool isAfterSameWord = false;
      if (afterIndex < currentSentence.length &&
          currentSentence.length >= afterIndex + word.length) {
        final nextWord =
            currentSentence.substring(afterIndex, afterIndex + word.length);
        if (nextWord == word) {
          // 같은 단어가 연속으로 오는 경우
          isAfterSameWord = true;
        }
      }

      // 연속된 단어의 경우: 앞이 같은 단어의 끝이어도 경계로 인식
      bool isAfterPreviousSameWord = false;
      if (foundIndex >= word.length) {
        final prevWord =
            currentSentence.substring(foundIndex - word.length, foundIndex);
        if (prevWord == word) {
          // 앞에 같은 단어가 있는 경우
          isAfterPreviousSameWord = true;
        }
      }

      // 경계 조건:
      // 1. 앞이 경계 문자이거나 같은 단어의 끝이고,
      // 2. 뒤는 경계 문자 또는 조사 또는 같은 단어의 시작 또는 문장 끝
      bool isValidBefore = _isWordBoundary(beforeChar) ||
          isAfterPreviousSameWord ||
          foundIndex == 0;
      bool isValidAfter = hasParticle ||
          _isWordBoundary(afterChar) ||
          isAfterSameWord ||
          afterIndex >= currentSentence.length;

      if (isValidBefore && isValidAfter) {
        // 이미 바뀐 위치인지 확인
        bool isAlreadyReplaced = false;
        for (final replacedPosition in _positionReplacements.keys) {
          if (replacedPosition == foundIndex) {
            isAlreadyReplaced = true;
            break;
          }
        }

        if (!isAlreadyReplaced) {
          positions.add(foundIndex);
        }
      }

      // 다음 검색 위치: 찾은 단어의 끝 위치로 이동 (연속된 단어도 찾기 위해)
      index = foundIndex + word.length;
    }
    return positions;
  }

  bool _isWordBoundary(String char) {
    return char == ' ' ||
        char == '\n' ||
        char == '\t' ||
        char == '.' ||
        char == ',' ||
        char == '!' ||
        char == '?' ||
        char == ';' ||
        char == ':';
  }

  void _updateSentenceAtPosition(
      String originalWord, String newWord, int position) {
    // originalWord는 길이 계산에만 사용됨 (실제로는 _positionReplacements에서 길이를 가져옴)
    if (position < 0 || position >= _sentence.length) return;

    // 한국어 조사 목록
    final koreanParticles = [
      '이',
      '가',
      '을',
      '를',
      '의',
      '에',
      '에서',
      '로',
      '으로',
      '와',
      '과',
      '도',
      '만',
      '부터',
      '까지',
      '처럼',
      '같이',
      '아',
      '야'
    ];

    // 이미 바뀐 단어인 경우, 저장된 길이 사용
    final currentLength =
        _positionReplacements[position]?.length ?? originalWord.length;

    // 실제로 문장에서 해당 위치에 있는 단어 확인
    if (position + currentLength > _sentence.length) return;

    // 조사가 있는지 확인
    int wordEndIndex = position + currentLength;
    String? foundParticle;

    if (wordEndIndex < _sentence.length) {
      for (final particle in koreanParticles) {
        if (_sentence.length >= wordEndIndex + particle.length) {
          final possibleParticle =
              _sentence.substring(wordEndIndex, wordEndIndex + particle.length);
          if (possibleParticle == particle) {
            // 조사 뒤에 경계 문자가 있는지 확인
            final afterParticleIndex = wordEndIndex + particle.length;
            if (afterParticleIndex >= _sentence.length ||
                _isWordBoundary(_sentence[afterParticleIndex])) {
              foundParticle = particle;
              break;
            }
          }
        }
      }
    }

    // 교체 수행
    final before = _sentence.substring(0, position);
    // 조사가 있으면 조사는 유지하고 단어만 교체
    final after = foundParticle != null
        ? _sentence.substring(position + currentLength) // 조사부터 끝까지
        : _sentence.substring(position + currentLength);

    // setState 없이 직접 업데이트 (호출하는 쪽에서 setState 처리)
    _sentence = before + newWord + after;
    _sentenceController.text = _sentence;
    _positionReplacements[position] = newWord;
  }

  // 단어 바꾸기 바텀 시트 표시
  void _showWordReplacementBottomSheet({
    required String currentWord,
    required List<String> synonyms,
    required Function(String) onReplace,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WordReplacementBottomSheet(
        currentWord: currentWord,
        synonyms: synonyms,
        onReplace: onReplace,
      ),
    );
  }

  Future<void> _saveCreation() async {
    if (_sentence.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문장을 작성해주세요.')),
      );
      return;
    }

    // 바텀 시트가 열려있는지 확인하고 닫기
    // 바텀 시트는 Navigator.canPop으로 확인 가능
    // 최대 2개의 바텀 시트가 열려있을 수 있음 (위치 선택 + 단어 바꾸기)
    int attempts = 0;
    while (Navigator.canPop(context) && attempts < 3) {
      // 바텀 시트가 열려있으면 닫기
      Navigator.pop(context);
      attempts++;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // _replacedWords 업데이트: _positionReplacements에 저장된 단어가 있으면 사용
      final updatedReplacedWords = List<String>.from(_replacedWords);
      if (_originalWords.isNotEmpty && _positionReplacements.isNotEmpty) {
        // _positionReplacements에서 첫 번째로 바뀐 단어 사용
        final replacedWord = _positionReplacements.values.first;
        updatedReplacedWords[0] = replacedWord;
      }

      final creation = Creation(
        originalWords: _originalWords,
        sentence: _sentence,
        replacedWords: updatedReplacedWords,
        createdAt: DateTime.now(),
      );

      // 개인 작품 저장 (항상 실행)
      final docId = await _firestoreService.saveCreation(creation);

      if (docId == null) {
        throw Exception('저장에 실패했습니다.');
      }

      // 커뮤니티 공유 (체크박스가 체크되어 있을 때만)
      if (_shareToCommunity && _originalWords.isNotEmpty) {
        try {
        final todayWord = _originalWords[0]; // 오늘의 단어
        await _firestoreService.savePublicCreationWithWord(
          creation,
          todayWord,
          DateTime.now(),
        );
        } catch (e) {
          // 공유 실패해도 개인 작품 저장은 성공했으므로 계속 진행
          print('커뮤니티 공유 실패: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _shareToCommunity ? '작품이 저장되고 커뮤니티에 공유되었습니다.' : '작품이 저장되었습니다.'),
          ),
        );
        // 현재 화면을 닫고 갤러리로 이동
        // 현재 화면을 갤러리로 교체
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const GalleryScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
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

  void _shareCreation() {
    if (_sentence.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문장을 작성해주세요.')),
      );
      return;
    }

    final shareText = '''
언어 스트레칭

원래 단어: ${_originalWords.isNotEmpty ? _originalWords[0] : ''}
작성한 문장: $_sentence
바꾼 단어: ${_replacedWords.isNotEmpty ? _replacedWords[0] : ''}

#언어스트레칭
''';

    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('클립보드에 복사되었습니다.')),
    );
  }

  @override
  void dispose() {
    _sentenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 작품 만들기'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 상단: 글감 (오늘의 단어)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '글감',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_originalWords.isNotEmpty)
                    Text(
                      _originalWords[0],
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),

            // 중단: 텍스트 에어리어
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '문장 작성',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        controller: _sentenceController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: '위 단어의 특징을 살려 문장을 작성해보세요...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _sentence = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 중하단: 단어 바꾸기
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading || _originalWords.isEmpty
                          ? null
                          : () => _replaceWord(0),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('단어 바꾸기'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 하단: 공유 및 저장
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 커뮤니티 공유 체크박스
                  Row(
                    children: [
                      Checkbox(
                        value: _shareToCommunity,
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _shareToCommunity = value ?? false;
                                });
                              },
                      ),
                      const Expanded(
                        child: Text(
                          '커뮤니티에 공유하기',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveCreation,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text(
                        '저장하기',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordPositionSelectionBottomSheet extends StatefulWidget {
  final String word;
  final String sentence;
  final List<int> positions;
  final Function(List<int>) onPositionsSelected;

  const _WordPositionSelectionBottomSheet({
    required this.word,
    required this.sentence,
    required this.positions,
    required this.onPositionsSelected,
  });

  @override
  State<_WordPositionSelectionBottomSheet> createState() =>
      _WordPositionSelectionBottomSheetState();
}

class _WordPositionSelectionBottomSheetState
    extends State<_WordPositionSelectionBottomSheet> {
  final Set<int> _selectedIndices = {};

  String _getContextAroundPosition(int position, int wordLength) {
    const contextLength = 20;
    final start = (position - contextLength).clamp(0, widget.sentence.length);
    final end = (position + wordLength + contextLength)
        .clamp(0, widget.sentence.length);
    var context = widget.sentence.substring(start, end);

    if (start > 0) context = '...$context';
    if (end < widget.sentence.length) context = '$context...';

    return context;
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIndices.clear();
      _selectedIndices.addAll(List.generate(widget.positions.length, (i) => i));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIndices.clear();
    });
  }

  Widget _buildHighlightedText(
      BuildContext context, int position, String word) {
    const contextLength = 20;
    final start = (position - contextLength).clamp(0, widget.sentence.length);
    final end = (position + word.length + contextLength)
        .clamp(0, widget.sentence.length);
    final sentenceContext = widget.sentence.substring(start, end);

    // 단어의 상대적 위치 계산
    final wordStartInContext = position - start;
    final wordEndInContext = wordStartInContext + word.length;

    // 앞뒤 텍스트
    final beforeText = start > 0
        ? '...${sentenceContext.substring(0, wordStartInContext)}'
        : sentenceContext.substring(0, wordStartInContext);
    final wordText =
        sentenceContext.substring(wordStartInContext, wordEndInContext);
    final afterText = end < widget.sentence.length
        ? '${sentenceContext.substring(wordEndInContext)}...'
        : sentenceContext.substring(wordEndInContext);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
        children: [
          TextSpan(text: beforeText),
          TextSpan(
            text: wordText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.5),
            ),
          ),
          TextSpan(text: afterText),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '"${widget.word}" 단어 위치 선택',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              '문장에 "${widget.word}"가 ${widget.positions.length}개 있습니다. 바꿀 위치를 선택하세요:',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 전체 선택/해제 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _selectAll,
                  child: const Text('전체 선택'),
                ),
                TextButton(
                  onPressed: _deselectAll,
                  child: const Text('전체 해제'),
                ),
              ],
            ),
          ),
          // 위치 목록
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: widget.positions.length,
              itemBuilder: (context, index) {
                final position = widget.positions[index];
                final isSelected = _selectedIndices.contains(index);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.3)
                      : null,
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(index),
                    ),
                    title:
                        _buildHighlightedText(context, position, widget.word),
                    subtitle: Text(
                      '위치: ${position + 1}번째 문자',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () => _toggleSelection(index),
                  ),
                );
              },
            ),
          ),
          // 하단 버튼
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedIndices.isEmpty
                        ? null
                        : () {
                            widget
                                .onPositionsSelected(_selectedIndices.toList());
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('바꾸기 (${_selectedIndices.length}개)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WordReplacementBottomSheet extends StatefulWidget {
  final String currentWord;
  final List<String> synonyms;
  final Function(String) onReplace;

  const _WordReplacementBottomSheet({
    required this.currentWord,
    required this.synonyms,
    required this.onReplace,
  });

  @override
  State<_WordReplacementBottomSheet> createState() =>
      _WordReplacementBottomSheetState();
}

class _WordReplacementBottomSheetState
    extends State<_WordReplacementBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  String? _selectedWord;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.currentWord;
    _selectedWord = widget.currentWord;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _confirmReplace() {
    final newWord = _textController.text.trim();
    if (newWord.isNotEmpty) {
      // 먼저 바텀 시트를 닫기
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      // 그 다음 상태 업데이트 (약간의 딜레이를 주어 바텀 시트가 완전히 닫힌 후)
      Future.delayed(const Duration(milliseconds: 200), () {
        widget.onReplace(newWord);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어를 입력해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 제목
            Row(
              children: [
                Expanded(
                  child: Text(
                    '단어 바꾸기',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 현재 단어 표시
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    '현재: ',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    widget.currentWord,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 새 단어 입력
            Text(
              '새 단어 입력',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '단어를 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                suffixIcon: _textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _textController.clear();
                            _selectedWord = null;
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _selectedWord = value.trim();
                });
              },
              onSubmitted: (_) => _confirmReplace(),
            ),
            if (widget.synonyms.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '추천 단어',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.synonyms.map((word) {
                  final isSelected = _selectedWord == word;
                  return FilterChip(
                    label: Text(word),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _textController.text = word;
                          _selectedWord = word;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
            // 확인 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmReplace,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
