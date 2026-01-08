class Creation {
  final int? id;
  final List<String> originalWords;
  final String sentence;
  final List<String> replacedWords;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Creation({
    this.id,
    required this.originalWords,
    required this.sentence,
    required this.replacedWords,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalWords': originalWords,
      'sentence': sentence,
      'replacedWords': replacedWords,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Creation.fromJson(Map<String, dynamic> json) {
    return Creation(
      id: json['id'] as int?,
      originalWords: List<String>.from(json['originalWords'] as List),
      sentence: json['sentence'] as String,
      replacedWords: List<String>.from(json['replacedWords'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Creation copyWith({
    int? id,
    List<String>? originalWords,
    String? sentence,
    List<String>? replacedWords,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Creation(
      id: id ?? this.id,
      originalWords: originalWords ?? this.originalWords,
      sentence: sentence ?? this.sentence,
      replacedWords: replacedWords ?? this.replacedWords,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

