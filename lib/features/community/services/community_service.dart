import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:vidhai/features/community/models/community_models.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const _uuid = Uuid();

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference get _postsRef => _firestore.collection('community_posts');
  CollectionReference get _commentsRef => _firestore.collection('community_comments');

  Future<CommunityPost?> createPost({
    required String content,
    String category = 'general',
    String district = '',
    String state = '',
    List<String> imageUrls = const [],
    bool isAIAssisted = false,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data();
      final authorName = userData?['displayName'] ?? 'Anonymous Farmer';
      final authorAvatar = userData?['avatarUrl'] ?? '';

      final postId = _uuid.v4();
      final post = CommunityPost(
        postId: postId,
        authorId: uid,
        authorName: authorName,
        authorAvatar: authorAvatar,
        content: content,
        imageUrls: imageUrls,
        category: category,
        district: district,
        state: state,
        createdAt: DateTime.now(),
        isAIAssisted: isAIAssisted,
      );

      await _postsRef.doc(postId).set(post.toMap());
      return post;
    } catch (_) {
      return null;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _postsRef.doc(postId).delete();
      final comments = await _commentsRef.where('postId', isEqualTo: postId).get();
      for (final doc in comments.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  Stream<List<CommunityPost>> getPostsStream({
    String? category,
    String? district,
    String? state,
    int limit = 20,
  }) {
    Query query = _postsRef.orderBy('createdAt', descending: true);

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    if (district != null && district.isNotEmpty) {
      query = query.where('district', isEqualTo: district);
    }
    if (state != null && state.isNotEmpty) {
      query = query.where('state', isEqualTo: state);
    }

    return query.limit(limit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return CommunityPost.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<void> toggleLike(CommunityPost post) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final likedBy = List<String>.from(post.likedBy);
      final isLiked = likedBy.contains(uid);

      if (isLiked) {
        likedBy.remove(uid);
      } else {
        likedBy.add(uid);
      }

      await _postsRef.doc(post.postId).update({
        'likes': likedBy.length,
        'likedBy': likedBy,
      });
    } catch (_) {}
  }

  Future<CommunityComment?> addComment({
    required String postId,
    required String content,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data();
      final authorName = userData?['displayName'] ?? 'Anonymous Farmer';

      final commentId = _uuid.v4();
      final comment = CommunityComment(
        commentId: commentId,
        postId: postId,
        authorId: uid,
        authorName: authorName,
        content: content,
        createdAt: DateTime.now(),
      );

      await _commentsRef.doc(commentId).set(comment.toMap());
      await _postsRef.doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      return comment;
    } catch (_) {
      return null;
    }
  }

  Stream<List<CommunityComment>> getCommentsStream(String postId) {
    return _commentsRef
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CommunityComment.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<int> getPostCount() async {
    try {
      final snapshot = await _postsRef.count().get();
      return snapshot.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getUserPostCount() async {
    final uid = _currentUserId;
    if (uid == null) return 0;
    try {
      final snapshot = await _postsRef.where('authorId', isEqualTo: uid).count().get();
      return snapshot.count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
