class Word {
  final String text;
  final String? meaning;
  final List<String>? synonyms;

  Word({
    required this.text,
    this.meaning,
    this.synonyms,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'meaning': meaning,
      'synonyms': synonyms,
    };
  }

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      text: json['text'] as String,
      meaning: json['meaning'] as String?,
      synonyms: json['synonyms'] != null
          ? List<String>.from(json['synonyms'] as List)
          : null,
    );
  }
}

