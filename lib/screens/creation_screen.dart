import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/creation.dart';
import '../services/word_service.dart';
import '../services/database_service.dart';
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
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialWord != null && widget.initialWord!.isNotEmpty) {
      setState(() {
        _originalWords = [widget.initialWord!];
        _replacedWords = [widget.initialWord!];
      });
    } else {
      _loadRandomWords();
    }
  }

  void _loadRandomWords() {
    setState(() {
      _originalWords = WordService.getRandomWords(count: 1);
      _replacedWords = List<String>.from(_originalWords);
    });
  }

  void _replaceWord(int index) {
    final currentWord = _replacedWords[index];
    final synonyms = WordService.getSynonyms(_originalWords[index]);
    
    showDialog(
      context: context,
      builder: (context) => _WordReplacementDialog(
        currentWord: currentWord,
        synonyms: synonyms,
        onReplace: (newWord) {
          setState(() {
            _replacedWords[index] = newWord;
            _updateSentence();
          });
        },
      ),
    );
  }

  void _updateSentence() {
    if (_originalWords.isNotEmpty && _replacedWords.isNotEmpty) {
      String updatedSentence = _sentence;
      updatedSentence = updatedSentence.replaceAll(
        _originalWords[0],
        _replacedWords[0],
      );
      _sentenceController.text = updatedSentence;
      _sentence = updatedSentence;
    }
  }

  Future<void> _saveCreation() async {
    if (_sentence.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문장을 작성해주세요.')),
      );
      return;
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

      await _dbService.insertCreation(creation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('작품이 저장되었습니다.')),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _shareCreation,
                    icon: const Icon(Icons.share),
                    label: const Text('공유하기'),
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

class _WordReplacementDialog extends StatelessWidget {
  final String currentWord;
  final List<String> synonyms;
  final Function(String) onReplace;

  const _WordReplacementDialog({
    required this.currentWord,
    required this.synonyms,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('단어 바꾸기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('현재: $currentWord'),
          const SizedBox(height: 16),
          const Text('대체 단어 선택:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: synonyms.map((word) {
              return ChoiceChip(
                label: Text(word),
                selected: word == currentWord,
                onSelected: (selected) {
                  if (selected) {
                    onReplace(word);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        ],
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

