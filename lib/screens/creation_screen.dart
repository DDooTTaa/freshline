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
    final originalWord = _originalWords[index];
    final synonyms = WordService.getSynonyms(originalWord);
    
    // 문장에서 해당 단어의 모든 위치 찾기 (이미 바뀐 위치는 제외)
    final wordPositions = _findWordPositionsInCurrentSentence(originalWord);
    
    if (wordPositions.length > 1) {
      // 여러 개가 있으면 위치 선택 다이얼로그 표시
      showDialog(
        context: context,
        builder: (context) => _WordPositionSelectionDialog(
          word: originalWord,
          sentence: _sentence,
          positions: wordPositions,
          onPositionSelected: (positionIndex) {
            Navigator.pop(context);
            final position = wordPositions[positionIndex];
            // 현재 해당 위치에 어떤 단어가 있는지 확인
            final currentWordAtPosition = _positionReplacements[position] ?? originalWord;
            
            // 선택한 위치의 단어를 바꾸기
            showDialog(
              context: context,
              builder: (context) => _WordReplacementDialog(
                currentWord: currentWordAtPosition,
                synonyms: synonyms,
                onReplace: (newWord) {
                  setState(() {
                    // 해당 위치를 새 단어로 교체
                    _positionReplacements[position] = newWord;
                    _updateSentenceAtPosition(originalWord, newWord, position);
                  });
                },
              ),
            );
          },
        ),
      );
    } else if (wordPositions.length == 1) {
      // 하나만 있으면 바로 단어 바꾸기 다이얼로그 표시
      final position = wordPositions[0];
      final currentWordAtPosition = _positionReplacements[position] ?? originalWord;
      
      showDialog(
        context: context,
        builder: (context) => _WordReplacementDialog(
          currentWord: currentWordAtPosition,
          synonyms: synonyms,
          onReplace: (newWord) {
            setState(() {
              _positionReplacements[position] = newWord;
              _updateSentenceAtPosition(originalWord, newWord, position);
            });
          },
        ),
      );
    }
  }
  
  List<int> _findWordPositionsInCurrentSentence(String word) {
    // 현재 문장에서 해당 단어의 위치를 찾되, 이미 바뀐 위치는 제외
    List<int> positions = [];
    int index = 0;
    final currentSentence = _sentence;
    
    while (index < currentSentence.length) {
      final foundIndex = currentSentence.indexOf(word, index);
      if (foundIndex == -1) break;
      
      // 단어 경계 확인
      final beforeChar = foundIndex > 0 ? currentSentence[foundIndex - 1] : ' ';
      final afterIndex = foundIndex + word.length;
      final afterChar = afterIndex < currentSentence.length ? currentSentence[afterIndex] : ' ';
      
      if (_isWordBoundary(beforeChar) && _isWordBoundary(afterChar)) {
        // 이 위치가 이미 바뀌지 않았는지 확인
        // (이미 바뀐 위치는 문장에 원래 단어가 없으므로 찾을 수 없음)
        positions.add(foundIndex);
      }
      
      index = foundIndex + 1;
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

  void _updateSentenceAtPosition(String originalWord, String newWord, int position) {
    if (position < 0 || position >= _sentence.length) return;
    
    // 실제로 문장에서 해당 위치에 있는 단어 확인
    final actualWordLength = originalWord.length;
    if (position + actualWordLength > _sentence.length) return;
    
    // 해당 위치의 단어가 실제로 원래 단어인지 확인
    final wordAtPosition = _sentence.substring(position, position + actualWordLength);
    if (wordAtPosition != originalWord) {
      // 이미 바뀐 단어인 경우, 현재 길이로 교체
      final currentLength = _positionReplacements[position]?.length ?? originalWord.length;
      final before = _sentence.substring(0, position);
      final after = _sentence.substring(position + currentLength);
      setState(() {
        _sentence = before + newWord + after;
        _sentenceController.text = _sentence;
        _positionReplacements[position] = newWord;
      });
      return;
    }
    
    final before = _sentence.substring(0, position);
    final after = _sentence.substring(position + actualWordLength);
    
    setState(() {
      _sentence = before + newWord + after;
      _sentenceController.text = _sentence;
      _positionReplacements[position] = newWord;
    });
  }

  Future<void> _saveCreation() async {
    if (_sentence.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문장을 작성해주세요.')),
      );
      return;
    }

    // 커뮤니티 공유 여부 확인
    if (!_shareToCommunity) {
      final shareConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('커뮤니티 공유'),
          content: const Text('이 작품을 커뮤니티에 공유하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('나중에'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('공유하기'),
            ),
          ],
        ),
      );
      _shareToCommunity = shareConfirmed ?? false;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final creation = Creation(
        originalWords: _originalWords,
        sentence: _sentence,
        replacedWords: _replacedWords,
        createdAt: DateTime.now(),
      );

      // 개인 작품 저장
      final docId = await _firestoreService.saveCreation(creation);
      
      if (docId == null) {
        throw Exception('저장에 실패했습니다.');
      }

      // 커뮤니티 공유
      if (_shareToCommunity && _originalWords.isNotEmpty) {
        final todayWord = _originalWords[0]; // 오늘의 단어
        await _firestoreService.savePublicCreationWithWord(
          creation,
          todayWord,
          DateTime.now(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_shareToCommunity 
                ? '작품이 저장되고 커뮤니티에 공유되었습니다.' 
                : '작품이 저장되었습니다.'),
          ),
        );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRandomWords,
            tooltip: '새 단어 받기',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '랜덤 단어',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_originalWords.isNotEmpty)
                      Center(
                        child: Chip(
                          label: Text(
                            _replacedWords[0],
                            style: const TextStyle(fontSize: 20),
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          onDeleted: () => _replaceWord(0),
                          deleteIcon: const Icon(Icons.edit, size: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '문장 작성',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sentenceController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: '위 단어의 특징을 살려 문장을 작성해보세요...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _sentence = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 커뮤니티 공유 체크박스
            Row(
              children: [
                Checkbox(
                  value: _shareToCommunity,
                  onChanged: _isLoading ? null : (value) {
                    setState(() {
                      _shareToCommunity = value ?? false;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    '커뮤니티에 공유하기',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _shareCreation,
                    icon: const Icon(Icons.share),
                    label: const Text('클립보드 복사'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveCreation,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('저장하기'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WordPositionSelectionDialog extends StatelessWidget {
  final String word;
  final String sentence;
  final List<int> positions;
  final Function(int) onPositionSelected;

  const _WordPositionSelectionDialog({
    required this.word,
    required this.sentence,
    required this.positions,
    required this.onPositionSelected,
  });

  String _getContextAroundPosition(int position, int wordLength) {
    const contextLength = 20;
    final start = (position - contextLength).clamp(0, sentence.length);
    final end = (position + wordLength + contextLength).clamp(0, sentence.length);
    var context = sentence.substring(start, end);
    
    if (start > 0) context = '...$context';
    if (end < sentence.length) context = '$context...';
    
    return context;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('"$word" 단어 위치 선택'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '문장에 "$word"가 ${positions.length}개 있습니다. 바꿀 위치를 선택하세요:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...positions.asMap().entries.map((entry) {
              final index = entry.key;
              final position = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    _getContextAroundPosition(position, word.length),
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '위치: ${position + 1}번째 문자',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    onPositionSelected(index);
                  },
                ),
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

class _WordReplacementDialog extends StatefulWidget {
  final String currentWord;
  final List<String> synonyms;
  final Function(String) onReplace;

  const _WordReplacementDialog({
    required this.currentWord,
    required this.synonyms,
    required this.onReplace,
  });

  @override
  State<_WordReplacementDialog> createState() => _WordReplacementDialogState();
}

class _WordReplacementDialogState extends State<_WordReplacementDialog> {
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
      widget.onReplace(newWord);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어를 입력해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('단어 바꾸기'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('현재: ${widget.currentWord}'),
            const SizedBox(height: 16),
            const Text('새 단어 입력:'),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: '단어를 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
              autofocus: true,
            ),
            if (widget.synonyms.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('또는 추천 단어 선택:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.synonyms.map((word) {
                  final isSelected = _selectedWord == word;
                  return ChoiceChip(
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _confirmReplace,
          child: const Text('확인'),
        ),
      ],
    );
  }
}

