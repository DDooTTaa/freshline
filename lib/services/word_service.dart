import 'dart:math';

class WordService {
  static final List<String> _words = [
    '바람',
    '물',
    '빛',
    '그림자',
    '시간',
    '기억',
    '꿈',
    '별',
    '하늘',
    '땅',
    '나무',
    '꽃',
    '새',
    '고양이',
    '강',
    '바다',
    '산',
    '구름',
    '비',
    '눈',
    '사랑',
    '슬픔',
    '기쁨',
    '두려움',
    '희망',
    '고독',
    '만남',
    '이별',
    '시작',
    '끝',
    '아침',
    '저녁',
    '밤',
    '낮',
    '봄',
    '여름',
    '가을',
    '겨울',
    '달',
    '태양',
    '길',
    '문',
    '창',
    '벽',
    '방',
    '집',
    '마을',
    '도시',
    '숲',
    '들판',
    '손',
    '발',
    '눈',
    '입',
    '귀',
    '마음',
    '영혼',
    '몸',
    '얼굴',
    '목소리',
    '책',
    '글',
    '말',
    '이야기',
    '노래',
    '춤',
    '그림',
    '색',
    '소리',
    '침묵',
    '웃음',
    '울음',
    '한숨',
    '부르짖음',
    '속삭임',
    '외침',
    '고백',
    '약속',
    '거짓말',
    '진실',
  ];

  static final Random _random = Random();

  /// 랜덤 단어들을 반환합니다
  static List<String> getRandomWords({int count = 3}) {
    final shuffled = List<String>.from(_words)..shuffle(_random);
    return shuffled.take(count).toList();
  }

  /// 특정 단어의 추천 단어를 반환합니다 (단어 풀에서 랜덤으로 10개)
  static List<String> getSynonyms(String word) {
    // 전체 단어 풀에서 현재 단어를 제외한 단어들
    final availableWords = _words.where((w) => w != word).toList();

    // 랜덤으로 섞기
    final shuffled = List<String>.from(availableWords)..shuffle(_random);

    // 10개만 선택 (단어 풀이 10개 미만이면 모두 반환)
    return shuffled.take(10).toList();
  }

  /// 단어 목록을 가져옵니다
  static List<String> getAllWords() {
    return List<String>.from(_words);
  }
}
