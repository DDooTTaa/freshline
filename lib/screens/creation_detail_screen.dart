import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/creation.dart';
import '../services/database_service.dart';

class CreationDetailScreen extends StatefulWidget {
  final Creation creation;

  const CreationDetailScreen({
    super.key,
    required this.creation,
  });

  @override
  State<CreationDetailScreen> createState() => _CreationDetailScreenState();
}

class _CreationDetailScreenState extends State<CreationDetailScreen> {
  late Creation _creation;
  final TextEditingController _sentenceController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _creation = widget.creation;
    _sentenceController.text = _creation.sentence;
  }

  @override
  void dispose() {
    _sentenceController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_sentenceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문장을 작성해주세요.')),
      );
      return;
    }

    try {
      final updatedCreation = _creation.copyWith(
        sentence: _sentenceController.text,
        updatedAt: DateTime.now(),
      );

      await _dbService.updateCreation(updatedCreation);

      setState(() {
        _creation = updatedCreation;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수정되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _shareCreation() {
    final shareText = '''
언어 스트레칭

원래 단어: ${_creation.originalWords.isNotEmpty ? _creation.originalWords[0] : ''}
작성한 문장: ${_creation.sentence}
바꾼 단어: ${_creation.replacedWords.isNotEmpty ? _creation.replacedWords[0] : ''}

#언어스트레칭
''';

    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('클립보드에 복사되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('작품 상세'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveChanges,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareCreation,
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
                      '원래 단어',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _creation.originalWords
                          .map((word) => Chip(
                                label: Text(word),
                                backgroundColor:
                                    Theme.of(context).colorScheme.surfaceVariant,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '작성한 문장',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isEditing
                        ? TextField(
                            controller: _sentenceController,
                            maxLines: 6,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        : Text(
                            _creation.sentence,
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1.6,
                            ),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '바꾼 단어',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                        _creation.originalWords.length,
                        (index) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(_creation.originalWords[index]),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.arrow_forward, size: 16),
                            ),
                            Chip(
                              label: Text(_creation.replacedWords[index]),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primaryContainer,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '작성일: ${DateFormat('yyyy년 MM월 dd일 HH:mm').format(_creation.createdAt)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_creation.updatedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '수정일: ${DateFormat('yyyy년 MM월 dd일 HH:mm').format(_creation.updatedAt!)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

