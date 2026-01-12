import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/creation.dart';
import 'word_service.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser?.uid ?? '';

  // 작품 저장
  Future<String?> saveCreation(Creation creation) async {
    if (_userId.isEmpty) {
      throw Exception('사용자가 로그인되지 않았습니다.');
    }

    try {
      final docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('creations')
          .add({
        'originalWords': creation.originalWords,
        'sentence': creation.sentence,
        'replacedWords': creation.replacedWords,
        'createdAt': Timestamp.fromDate(creation.createdAt),
        'updatedAt': creation.updatedAt != null
            ? Timestamp.fromDate(creation.updatedAt!)
            : null,
      });

      return docRef.id;
    } catch (e) {
      print('작품 저장 오류: $e');
      return null;
    }
  }

  // 작품 목록 가져오기
  Future<List<Creation>> getCreations() async {
    if (_userId.isEmpty) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('creations')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Creation(
          docId: doc.id,
          originalWords: List<String>.from(data['originalWords'] ?? []),
          sentence: data['sentence'] ?? '',
          replacedWords: List<String>.from(data['replacedWords'] ?? []),
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          updatedAt: data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
        );
      }).toList();
    } catch (e) {
      print('작품 목록 가져오기 오류: $e');
      return [];
    }
  }

  // 실시간 작품 목록 스트림
  Stream<List<Creation>> getCreationsStream() {
    if (_userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('creations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Creation(
          docId: doc.id,
          originalWords: List<String>.from(data['originalWords'] ?? []),
          sentence: data['sentence'] ?? '',
          replacedWords: List<String>.from(data['replacedWords'] ?? []),
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          updatedAt: data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
        );
      }).toList();
    });
  }

  // 작품 업데이트
  Future<bool> updateCreation(String docId, Creation creation) async {
    if (_userId.isEmpty) {
      return false;
    }

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('creations')
          .doc(docId)
          .update({
        'sentence': creation.sentence,
        'replacedWords': creation.replacedWords,
        'updatedAt': Timestamp.fromDate(creation.updatedAt ?? DateTime.now()),
      });

      return true;
    } catch (e) {
      print('작품 업데이트 오류: $e');
      return false;
    }
  }

  // 작품 삭제
  Future<bool> deleteCreation(String docId) async {
    if (_userId.isEmpty) {
      return false;
    }

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('creations')
          .doc(docId)
          .delete();

      return true;
    } catch (e) {
      print('작품 삭제 오류: $e');
      return false;
    }
  }

  // 공개 작품 저장 (커뮤니티 공유용)
  Future<String?> savePublicCreation(Creation creation) async {
    if (_userId.isEmpty) {
      throw Exception('사용자가 로그인되지 않았습니다.');
    }

    try {
      final docRef = await _firestore.collection('public_creations').add({
        'userId': _userId,
        'userName': _auth.currentUser?.displayName ?? '익명',
        'userPhoto': _auth.currentUser?.photoURL ?? '',
        'originalWords': creation.originalWords,
        'sentence': creation.sentence,
        'replacedWords': creation.replacedWords,
        'createdAt': Timestamp.fromDate(creation.createdAt),
        'likeCount': 0,
      });

      return docRef.id;
    } catch (e) {
      print('공개 작품 저장 오류: $e');
      return null;
    }
  }

  // 공개 작품 목록 가져오기
  Stream<List<Map<String, dynamic>>> getPublicCreations() {
    return _firestore
        .collection('public_creations')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();
    });
  }

  // 좋아요 추가/제거
  Future<void> toggleLike(String creationId) async {
    if (_userId.isEmpty) return;

    try {
      final docRef = _firestore.collection('public_creations').doc(creationId);
      final doc = await docRef.get();

      if (!doc.exists) return;

      final likes = doc.data()?['likes'] as List<dynamic>? ?? [];
      final hasLiked = likes.contains(_userId);

      if (hasLiked) {
        await docRef.update({
          'likes': FieldValue.arrayRemove([_userId]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await docRef.update({
          'likes': FieldValue.arrayUnion([_userId]),
          'likeCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      print('좋아요 토글 오류: $e');
    }
  }

  // 날짜 문자열 생성 (YYYY-MM-DD 형식)
  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Firebase에서 단어 풀 가져오기
  Future<List<String>> _getWordPool() async {
    try {
      final snapshot = await _firestore.collection('word_pool').get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => doc.data()['word'] as String)
            .where((word) => word.isNotEmpty)
            .toList();
      }
    } catch (e) {
      print('단어 풀 가져오기 오류: $e');
    }
    // Firebase에 단어 풀이 없으면 기본 단어 목록 사용
    return WordService.getAllWords();
  }

  // 최근 사용된 단어 목록 가져오기 (중복 방지용)
  Future<List<String>> _getRecentWords(int days) async {
    try {
      final now = DateTime.now();
      final recentDates = List.generate(days, (i) => _getDateString(now.subtract(Duration(days: i))));
      
      final futures = recentDates.map((date) => 
        _firestore.collection('daily_words').doc(date).get()
      );
      
      final docs = await Future.wait(futures);
      return docs
          .where((doc) => doc.exists && doc.data() != null)
          .map((doc) => doc.data()!['word'] as String)
          .toList();
    } catch (e) {
      print('최근 단어 가져오기 오류: $e');
      return [];
    }
  }

  // 오늘의 단어 가져오기
  Future<String> getTodayWord() async {
    final today = _getDateString(DateTime.now());
    
    // 먼저 오늘의 단어가 있는지 확인 (읽기만)
    try {
      final doc = await _firestore.collection('daily_words').doc(today).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['word'] as String;
      }
    } catch (e) {
      print('오늘의 단어 읽기 오류: $e');
      // 읽기 실패 시 기본 단어 반환
      return WordService.getRandomWords(count: 1).first;
    }
    
    // 오늘의 단어가 없으면 생성 (인증된 사용자만 가능)
    try {
      // 최근 단어 가져오기 (실패해도 계속 진행)
      List<String> recentWords = [];
      try {
        recentWords = await _getRecentWords(7);
      } catch (e) {
        print('최근 단어 가져오기 실패 (무시하고 계속): $e');
      }
      
      // 단어 풀 가져오기
      final wordPool = await _getWordPool();
      
      // 최근 7일간 사용된 단어는 제외하여 중복 방지
      final availableWords = wordPool.where((word) => !recentWords.contains(word)).toList();
      
      String selectedWord;
      if (availableWords.isNotEmpty) {
        availableWords.shuffle();
        selectedWord = availableWords.first;
      } else {
        // 모든 단어를 사용했으면 전체 풀에서 선택
        final shuffledPool = List<String>.from(wordPool)..shuffle();
        selectedWord = shuffledPool.first;
      }
      
      // 트랜잭션을 사용하여 동시성 문제 해결
      try {
        return await _firestore.runTransaction<String>((transaction) async {
          final docRef = _firestore.collection('daily_words').doc(today);
          final doc = await transaction.get(docRef);
          
          if (doc.exists && doc.data() != null) {
            return doc.data()!['word'] as String;
          } else {
            transaction.set(docRef, {
              'word': selectedWord,
              'date': Timestamp.fromDate(DateTime.now()),
              'createdAt': Timestamp.now(),
              'source': 'auto_generated', // 자동 생성됨을 표시
            });
            return selectedWord;
          }
        });
      } catch (e) {
        print('트랜잭션 오류: $e');
        // 트랜잭션 실패 시 직접 쓰기 시도
        try {
          await _firestore.collection('daily_words').doc(today).set({
            'word': selectedWord,
            'date': Timestamp.fromDate(DateTime.now()),
            'createdAt': Timestamp.now(),
            'source': 'auto_generated',
          });
          return selectedWord;
        } catch (e2) {
          print('직접 쓰기 오류: $e2');
          // 쓰기 실패해도 선택된 단어 반환
          return selectedWord;
        }
      }
    } catch (e) {
      print('오늘의 단어 생성 오류: $e');
      // 최종 실패 시 기본 단어 반환
      return WordService.getRandomWords(count: 1).first;
    }
  }

  // 특정 날짜의 단어 가져오기
  Future<String?> getWordByDate(DateTime date) async {
    final dateStr = _getDateString(date);
    
    try {
      final doc = await _firestore.collection('daily_words').doc(dateStr).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['word'] as String;
      }
      return null;
    } catch (e) {
      print('날짜별 단어 가져오기 오류: $e');
      return null;
    }
  }

  // 날짜별 단어 설정 (관리자용)
  Future<bool> setWordForDate(DateTime date, String word) async {
    final dateStr = _getDateString(date);
    
    try {
      await _firestore.collection('daily_words').doc(dateStr).set({
        'word': word,
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.now(),
        'source': 'manual', // 수동 설정됨을 표시
      });
      return true;
    } catch (e) {
      print('날짜별 단어 설정 오류: $e');
      return false;
    }
  }


  // 공개 작품 저장 (오늘의 단어 포함)
  Future<String?> savePublicCreationWithWord(Creation creation, String word, DateTime wordDate) async {
    if (_userId.isEmpty) {
      throw Exception('사용자가 로그인되지 않았습니다.');
    }

    try {
      final dateStr = _getDateString(wordDate);
      final docRef = await _firestore.collection('public_creations').add({
        'userId': _userId,
        'userName': _auth.currentUser?.displayName ?? '익명',
        'userPhoto': _auth.currentUser?.photoURL ?? '',
        'word': word,
        'wordDate': dateStr,
        'originalWords': creation.originalWords,
        'sentence': creation.sentence,
        'replacedWords': creation.replacedWords,
        'createdAt': Timestamp.fromDate(creation.createdAt),
        'likeCount': 0,
        'likes': <String>[],
      });

      return docRef.id;
    } catch (e) {
      print('공개 작품 저장 오류: $e');
      return null;
    }
  }

  // 오늘의 단어에 대한 공개 작품 목록 가져오기 (daily_words에서 가져온 단어 사용)
  Stream<List<Map<String, dynamic>>> getTodayWordCreations() {
    final today = _getDateString(DateTime.now());
    
    // daily_words에서 오늘의 단어를 가져와서 필터링
    // 날짜로 필터링 (wordDate 필드 사용)
    // orderBy 없이 가져온 후 클라이언트에서 정렬 (인덱스 문제 방지)
    return _firestore
        .collection('public_creations')
        .where('wordDate', isEqualTo: today)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();
      
      // 클라이언트에서 날짜순 정렬
      list.sort((a, b) {
        final aDate = a['createdAt'] as DateTime;
        final bDate = b['createdAt'] as DateTime;
        return bDate.compareTo(aDate); // 내림차순
      });
      
      return list;
    });
  }

  // 오늘의 단어 가져오기 (daily_words에서)
  Future<String> getTodayWordFromDailyWords() async {
    final today = _getDateString(DateTime.now());
    
    try {
      final doc = await _firestore.collection('daily_words').doc(today).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['word'] as String;
      }
    } catch (e) {
      print('daily_words에서 오늘의 단어 가져오기 오류: $e');
    }
    
    // 없으면 기본 단어 반환
    return WordService.getRandomWords(count: 1).first;
  }

  // 특정 날짜의 공개 작품 목록 가져오기
  Stream<List<Map<String, dynamic>>> getWordCreationsByDate(DateTime date) {
    final dateStr = _getDateString(date);
    
    return _firestore
        .collection('public_creations')
        .where('wordDate', isEqualTo: dateStr)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();
    });
  }

  // 단어 풀 초기화 (Firebase에 단어 추가)
  Future<bool> initializeWordPool() async {
    try {
      // 기존 단어 풀 확인
      final existingSnapshot = await _firestore.collection('word_pool').get();
      if (existingSnapshot.docs.isNotEmpty) {
        print('단어 풀이 이미 존재합니다. (${existingSnapshot.docs.length}개 단어)');
        return true;
      }

      // WordService에서 모든 단어 가져오기
      final words = WordService.getAllWords();
      
      // Firebase에 단어 추가
      final batch = _firestore.batch();
      for (final word in words) {
        final docRef = _firestore.collection('word_pool').doc();
        batch.set(docRef, {
          'word': word,
          'createdAt': Timestamp.now(),
        });
      }
      
      await batch.commit();
      print('단어 풀 초기화 완료: ${words.length}개 단어 추가됨');
      return true;
    } catch (e) {
      print('단어 풀 초기화 오류: $e');
      return false;
    }
  }

  // 단어 풀에 단어 추가
  Future<bool> addWordToPool(String word) async {
    try {
      // 중복 확인
      final existingSnapshot = await _firestore
          .collection('word_pool')
          .where('word', isEqualTo: word)
          .get();
      
      if (existingSnapshot.docs.isNotEmpty) {
        print('이미 존재하는 단어입니다: $word');
        return false;
      }

      await _firestore.collection('word_pool').add({
        'word': word,
        'createdAt': Timestamp.now(),
      });
      
      print('단어 추가 완료: $word');
      return true;
    } catch (e) {
      print('단어 추가 오류: $e');
      return false;
    }
  }

  // 단어 풀 목록 가져오기 (관리자용)
  Future<List<String>> getWordPool() async {
    return await _getWordPool();
  }

  // 날짜별 단어와 예시 문장 일괄 설정 (오늘부터 시작)
  Future<bool> initializeDailyWordsWithExamples() async {
    // 인증 확인
    if (_auth.currentUser == null) {
      print('날짜별 단어 초기화 오류: 로그인이 필요합니다.');
      return false;
    }

    try {
      // 단어 목록과 각 단어에 대한 예시 문장
      final wordsWithExamples = [
        {'word': '바람', 'example': '바람이 창문을 두드리며 나를 깨운다.'},
        {'word': '물', 'example': '물은 가장 부드러우면서도 가장 강하다.'},
        {'word': '빛', 'example': '빛이 어둠을 가르며 새벽이 온다.'},
        {'word': '그림자', 'example': '그림자는 나의 가장 충실한 동반자다.'},
        {'word': '시간', 'example': '시간은 흐르지만 기억은 남는다.'},
        {'word': '기억', 'example': '기억은 때로는 달콤하고 때로는 쓰다.'},
        {'word': '꿈', 'example': '꿈은 현실이 되기 전까지는 불가능해 보인다.'},
        {'word': '별', 'example': '별은 어둠 속에서도 빛을 잃지 않는다.'},
        {'word': '하늘', 'example': '하늘은 끝이 없어서 자유롭다.'},
        {'word': '땅', 'example': '땅은 모든 것을 받아들이고 키운다.'},
        {'word': '나무', 'example': '나무는 뿌리 깊이 땅에 박혀 서 있다.'},
        {'word': '꽃', 'example': '꽃은 아름다움을 위해 피어난다.'},
        {'word': '새', 'example': '새는 하늘을 향해 날아오른다.'},
        {'word': '고양이', 'example': '고양이는 독립적이지만 따뜻함을 안다.'},
        {'word': '강', 'example': '강은 멈추지 않고 흘러간다.'},
        {'word': '바다', 'example': '바다는 넓어서 모든 것을 품는다.'},
        {'word': '산', 'example': '산은 높아서 하늘에 닿으려 한다.'},
        {'word': '구름', 'example': '구름은 자유롭게 떠다닌다.'},
        {'word': '비', 'example': '비는 땅을 적시고 생명을 준다.'},
        {'word': '눈', 'example': '눈은 조용히 내려와 세상을 덮는다.'},
        {'word': '사랑', 'example': '사랑은 주는 것에서 시작된다.'},
        {'word': '슬픔', 'example': '슬픔은 깊어질수록 성장의 씨앗이 된다.'},
        {'word': '기쁨', 'example': '기쁨은 작은 순간에서 찾을 수 있다.'},
        {'word': '두려움', 'example': '두려움은 용기를 만드는 재료다.'},
        {'word': '희망', 'example': '희망은 어둠 속에서도 빛을 낸다.'},
        {'word': '고독', 'example': '고독은 나를 만나는 시간이다.'},
        {'word': '만남', 'example': '만남은 우연이 아닌 필연이다.'},
        {'word': '이별', 'example': '이별은 새로운 시작을 위한 문이다.'},
        {'word': '시작', 'example': '시작은 한 걸음에서 온다.'},
        {'word': '끝', 'example': '끝은 또 다른 시작의 시작이다.'},
        {'word': '아침', 'example': '아침은 새로운 하루의 시작이다.'},
        {'word': '저녁', 'example': '저녁은 하루를 마무리하는 시간이다.'},
        {'word': '밤', 'example': '밤은 휴식과 꿈의 시간이다.'},
        {'word': '낮', 'example': '낮은 활동과 빛의 시간이다.'},
        {'word': '봄', 'example': '봄은 모든 것이 새롭게 시작되는 계절이다.'},
        {'word': '여름', 'example': '여름은 뜨거운 열정의 계절이다.'},
        {'word': '가을', 'example': '가을은 풍성한 수확의 계절이다.'},
        {'word': '겨울', 'example': '겨울은 침묵과 성찰의 계절이다.'},
        {'word': '달', 'example': '달은 밤하늘의 등불이다.'},
        {'word': '태양', 'example': '태양은 모든 생명의 원천이다.'},
        {'word': '길', 'example': '길은 걸어야 비로소 길이 된다.'},
        {'word': '문', 'example': '문은 열면 새로운 세계가 보인다.'},
        {'word': '창', 'example': '창은 밖을 보는 눈이다.'},
        {'word': '벽', 'example': '벽은 넘어야 할 장애물이다.'},
        {'word': '방', 'example': '방은 나만의 안전한 공간이다.'},
        {'word': '집', 'example': '집은 마음이 편안해지는 곳이다.'},
        {'word': '마을', 'example': '마을은 따뜻한 이웃이 있는 곳이다.'},
        {'word': '도시', 'example': '도시는 꿈을 실현하는 무대다.'},
        {'word': '숲', 'example': '숲은 자연의 신비가 숨어있는 곳이다.'},
        {'word': '들판', 'example': '들판은 끝없이 펼쳐진 자유다.'},
        {'word': '손', 'example': '손은 마음을 전달하는 도구다.'},
        {'word': '발', 'example': '발은 나를 원하는 곳으로 데려간다.'},
        {'word': '눈', 'example': '눈은 세상을 보는 창이다.'},
        {'word': '입', 'example': '입은 말과 미소를 만든다.'},
        {'word': '귀', 'example': '귀는 마음을 듣는 창이다.'},
        {'word': '마음', 'example': '마음은 모든 감정의 근원이다.'},
        {'word': '영혼', 'example': '영혼은 몸을 넘어서는 존재다.'},
        {'word': '몸', 'example': '몸은 영혼이 머무는 집이다.'},
        {'word': '얼굴', 'example': '얼굴은 마음의 거울이다.'},
        {'word': '목소리', 'example': '목소리는 마음을 전달하는 소리다.'},
        {'word': '책', 'example': '책은 지식과 상상력의 창고다.'},
        {'word': '글', 'example': '글은 생각을 기록하는 도구다.'},
        {'word': '말', 'example': '말은 마음을 전하는 다리다.'},
        {'word': '이야기', 'example': '이야기는 경험을 공유하는 방법이다.'},
        {'word': '노래', 'example': '노래는 마음을 표현하는 음악이다.'},
        {'word': '춤', 'example': '춤은 몸으로 표현하는 예술이다.'},
        {'word': '그림', 'example': '그림은 눈으로 보는 시다.'},
        {'word': '색', 'example': '색은 감정을 표현하는 언어다.'},
        {'word': '소리', 'example': '소리는 세상을 듣게 만든다.'},
        {'word': '침묵', 'example': '침묵은 때로 가장 큰 소리다.'},
        {'word': '웃음', 'example': '웃음은 마음을 밝게 만든다.'},
        {'word': '울음', 'example': '울음은 감정을 해소하는 방법이다.'},
        {'word': '한숨', 'example': '한숨은 깊은 생각의 표현이다.'},
        {'word': '부르짖음', 'example': '부르짖음은 마음의 외침이다.'},
        {'word': '속삭임', 'example': '속삭임은 비밀스러운 대화다.'},
        {'word': '외침', 'example': '외침은 강한 의지의 표현이다.'},
        {'word': '고백', 'example': '고백은 용기 있는 사랑의 표현이다.'},
        {'word': '약속', 'example': '약속은 신뢰의 기반이다.'},
        {'word': '거짓말', 'example': '거짓말은 진실을 가리는 그림자다.'},
        {'word': '진실', 'example': '진실은 때로 아프지만 자유롭게 만든다.'},
      ];

      final today = DateTime.now();
      final batch = _firestore.batch();
      int addedCount = 0;

      for (int i = 0; i < wordsWithExamples.length; i++) {
        final date = today.add(Duration(days: i));
        final dateStr = _getDateString(date);
        final wordData = wordsWithExamples[i];
        
        // 이미 해당 날짜에 단어가 있는지 확인
        final existingDoc = await _firestore.collection('daily_words').doc(dateStr).get();
        if (existingDoc.exists) {
          print('${dateStr} 날짜의 단어가 이미 존재합니다. 건너뜁니다.');
          continue;
        }

        final docRef = _firestore.collection('daily_words').doc(dateStr);
        batch.set(docRef, {
          'word': wordData['word'],
          'example': wordData['example'],
          'date': Timestamp.fromDate(date),
          'createdAt': Timestamp.now(),
          'source': 'manual', // 수동 설정
        });
        addedCount++;
      }

      if (addedCount > 0) {
        await batch.commit();
        print('날짜별 단어 초기화 완료: ${addedCount}개 날짜에 단어 추가됨');
      } else {
        print('추가할 날짜별 단어가 없습니다.');
      }

      return true;
    } catch (e) {
      print('날짜별 단어 초기화 오류: $e');
      return false;
    }
  }
}
