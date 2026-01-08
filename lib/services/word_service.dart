import 'dart:math';

class WordService {
  static final List<String> _words = [
    '바람', '물', '빛', '그림자', '시간', '기억', '꿈', '별', '하늘', '땅',
    '나무', '꽃', '새', '고양이', '강', '바다', '산', '구름', '비', '눈',
    '사랑', '슬픔', '기쁨', '두려움', '희망', '고독', '만남', '이별', '시작', '끝',
    '아침', '저녁', '밤', '낮', '봄', '여름', '가을', '겨울', '달', '태양',
    '길', '문', '창', '벽', '방', '집', '마을', '도시', '숲', '들판',
    '손', '발', '눈', '입', '귀', '마음', '영혼', '몸', '얼굴', '목소리',
    '책', '글', '말', '이야기', '노래', '춤', '그림', '색', '소리', '침묵',
    '웃음', '울음', '한숨', '부르짖음', '속삭임', '외침', '고백', '약속', '거짓말', '진실',
  ];

  static final Random _random = Random();

  /// 랜덤 단어들을 반환합니다
  static List<String> getRandomWords({int count = 3}) {
    final shuffled = List<String>.from(_words)..shuffle(_random);
    return shuffled.take(count).toList();
  }

  /// 특정 단어의 유사어를 반환합니다
  static List<String> getSynonyms(String word) {
    final synonymMap = {
      '바람': ['바람', '산들바람', '강풍', '미풍'],
      '물': ['물', '한 방울', '강물', '바닷물'],
      '빛': ['빛', '햇빛', '달빛', '별빛'],
      '그림자': ['그림자', '어둠', '흔적'],
      '시간': ['시간', '순간', '때', '지금'],
      '기억': ['기억', '추억', '과거'],
      '꿈': ['꿈', '환상', '희망'],
      '별': ['별', '항성', '반짝임'],
      '하늘': ['하늘', '천공', '창공'],
      '땅': ['땅', '대지', '흙'],
    };

    return synonymMap[word] ?? [word];
  }

  /// 단어 목록을 가져옵니다
  static List<String> getAllWords() {
    return List<String>.from(_words);
  }
}

