class Creation {
  final int? id; // SQLite용 (하위 호환성)
  final String? docId; // Firestore document ID
  final List<String> originalWords;
  final String sentence;
  final List<String> replacedWords;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Creation({
    this.id,
    this.docId,
    required this.originalWords,
    required this.sentence,
    required this.replacedWords,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'docId': docId,
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
      docId: json['docId'] as String?,
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
    String? docId,
    List<String>? originalWords,
    String? sentence,
    List<String>? replacedWords,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Creation(
      id: id ?? this.id,
      docId: docId ?? this.docId,
      originalWords: originalWords ?? this.originalWords,
      sentence: sentence ?? this.sentence,
      replacedWords: replacedWords ?? this.replacedWords,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

