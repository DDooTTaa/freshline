import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/creation.dart';

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
          id: int.tryParse(doc.id),
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
        'updatedAt': Timestamp.fromDate(DateTime.now()),
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
}
