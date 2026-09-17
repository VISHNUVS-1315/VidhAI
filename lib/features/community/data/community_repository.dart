import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/services/data_service.dart';

/// Single-collection real-time data access for the Community module.
///
/// Community post photos are stored as small inline data URLs in Firestore so
/// the Spark-plan build does not depend on a Firebase Storage bucket. Legacy
/// Firebase Storage URLs remain readable/deletable on a best-effort basis.
class CommunityRepository {
  CommunityRepository._();
  static final CommunityRepository instance = CommunityRepository._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  static const _communityCollection = 'community_posts';
  static const _activityCollection = 'community_activity';
  static const pageSize = 20;

  // Base64 adds roughly 33% overhead. Keeping the picked image below this
  // leaves comfortable room under Firestore's 1 MiB document limit.
  static const _maxInlineImageBytes = 550 * 1024;

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _db.collection(_communityCollection);

  String? get _uid => _auth.currentUser?.uid;

  Query<Map<String, dynamic>> _baseQuery(CommunityPostType type) =>
      _postsRef.where('type', isEqualTo: type.value);

  Query<Map<String, dynamic>> experienceQuery({
    String? district,
    int limit = pageSize,
  }) {
    Query<Map<String, dynamic>> q = _baseQuery(CommunityPostType.experience)
        .where('status', isEqualTo: CommunityStatus.active.value);
    if (district != null && district.isNotEmpty) {
      q = q.where('district', isEqualTo: district);
    }
    return q.orderBy('createdAt', descending: true).limit(limit);
  }

  Query<Map<String, dynamic>> harvestQuery({
    String? district,
    int limit = pageSize,
  }) {
    Query<Map<String, dynamic>> q = _baseQuery(CommunityPostType.harvest)
        .where('status', isEqualTo: CommunityStatus.active.value)
        .where('harvestDate', isGreaterThanOrEqualTo: Timestamp.now());
    if (district != null && district.isNotEmpty) {
      q = q.where('district', isEqualTo: district);
    }
    return q.orderBy('harvestDate').limit(limit);
  }

  Query<Map<String, dynamic>> demandQuery({
    String? district,
    int limit = pageSize,
  }) {
    Query<Map<String, dynamic>> q = _baseQuery(CommunityPostType.demand)
        .where('status', isEqualTo: CommunityStatus.active.value);
    if (district != null && district.isNotEmpty) {
      q = q.where('district', isEqualTo: district);
    }
    return q.orderBy('createdAt', descending: true).limit(limit);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> experienceStream({
    String? district,
    int limit = pageSize,
  }) =>
      experienceQuery(district: district, limit: limit).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> harvestStream({
    String? district,
    int limit = pageSize,
  }) =>
      harvestQuery(district: district, limit: limit).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> demandStream({
    String? district,
    int limit = pageSize,
  }) =>
      demandQuery(district: district, limit: limit).snapshots();

  Future<(List<CommunityPost>, DocumentSnapshot<Map<String, dynamic>>?)>
      loadMore({
    required CommunityPostType type,
    required String? district,
    required DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = pageSize,
  }) async {
    Query<Map<String, dynamic>> q;

    switch (type) {
      case CommunityPostType.harvest:
        q = _baseQuery(CommunityPostType.harvest)
            .where('status', isEqualTo: CommunityStatus.active.value)
            .where('harvestDate', isGreaterThanOrEqualTo: Timestamp.now());
        if (district != null && district.isNotEmpty) {
          q = q.where('district', isEqualTo: district);
        }
        q = q.orderBy('harvestDate');
        break;
      case CommunityPostType.demand:
        q = _baseQuery(CommunityPostType.demand)
            .where('status', isEqualTo: CommunityStatus.active.value);
        if (district != null && district.isNotEmpty) {
          q = q.where('district', isEqualTo: district);
        }
        q = q.orderBy('createdAt', descending: true);
        break;
      case CommunityPostType.experience:
        q = _baseQuery(CommunityPostType.experience)
            .where('status', isEqualTo: CommunityStatus.active.value);
        if (district != null && district.isNotEmpty) {
          q = q.where('district', isEqualTo: district);
        }
        q = q.orderBy('createdAt', descending: true);
        break;
    }

    if (after != null) q = q.startAfterDocument(after);

    final snap = await q.limit(limit + 1).get();
    final hasMore = snap.docs.length > limit;
    final docs = snap.docs.take(limit).toList();
    final lastDoc = hasMore && docs.isNotEmpty ? docs.last : null;

    return (docs.map(CommunityPost.fromFirestore).toList(), lastDoc);
  }

  Query<Map<String, dynamic>> myPostsQuery({int limit = 50}) => _postsRef
      .where('authorId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .limit(limit);

  Stream<QuerySnapshot<Map<String, dynamic>>> myPostsStream({int limit = 50}) =>
      myPostsQuery(limit: limit).snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> postDocStream(String postId) =>
      _postsRef.doc(postId).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> myActivityStream({
    int limit = 50,
  }) {
    final uid = _uid;
    if (uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _db
        .collection('users')
        .doc(uid)
        .collection(_activityCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<int> unreadActivityCountStream() {
    final uid = _uid;
    if (uid == null) return Stream<int>.value(0);
    return _db
        .collection('users')
        .doc(uid)
        .collection(_activityCollection)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markActivityRead(String activityId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection(_activityCollection)
          .doc(activityId)
          .update({'read': true});
    } catch (e) {
      debugPrint('[CommunityRepo] markActivityRead failed: $e');
    }
  }

  Future<void> markAllActivityRead() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection(_activityCollection)
          .where('read', isEqualTo: false)
          .limit(200)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[CommunityRepo] markAllActivityRead failed: $e');
    }
  }

  Future<void> deleteActivity(String activityId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection(_activityCollection)
          .doc(activityId)
          .delete();
    } catch (e) {
      debugPrint('[CommunityRepo] deleteActivity failed: $e');
    }
  }

  Future<String?> createPost({
    required CommunityPostType type,
    required String state,
    required String district,
    String farmId = '',
    String farmName = '',
    String cropId = '',
    required String cropName,
    String imageUrl = '',
    String description = '',
    String title = '',
    String experienceText = '',
    double? quantityKg,
    DateTime? harvestDate,
    double? askingPricePerKg,
    double? marketReferencePerKg,
    double? suggestedMinPrice,
    double? suggestedMaxPrice,
    String? priceRiskLevel,
    DateTime? requiredDate,
    double? targetPricePerKg,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final profile = await DataService().loadProfile();
    final postId = _postsRef.doc().id;

    final post = CommunityPost(
      id: postId,
      authorId: uid,
      authorName: profile?.displayName ?? 'Anonymous Farmer',
      authorPhoto: profile?.avatarUrl ?? '',
      type: type,
      state: state,
      district: district,
      farmId: farmId,
      farmName: farmName,
      cropId: cropId,
      cropName: cropName,
      imageUrl: imageUrl,
      description: description,
      createdAt: DateTime.now(),
      title: title,
      experienceText: experienceText,
      quantityKg: quantityKg,
      harvestDate: harvestDate,
      askingPricePerKg: askingPricePerKg,
      marketReferencePerKg: marketReferencePerKg,
      suggestedMinPrice: suggestedMinPrice,
      suggestedMaxPrice: suggestedMaxPrice,
      priceRiskLevel: priceRiskLevel,
      requiredDate: requiredDate,
      targetPricePerKg: targetPricePerKg,
    );

    await _postsRef.doc(postId).set(post.toMap());
    return postId;
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _postsRef.doc(postId).update(data);
  }

  Future<void> deletePost(String postId) async {
    final postRef = _postsRef.doc(postId);
    String imageUrl = '';

    try {
      final snap = await postRef.get();
      imageUrl = (snap.data()?['imageUrl'] ?? '') as String;
    } catch (_) {}

    await postRef.delete();

    for (final sub in ['comments', 'likes', 'interests', 'suppliers']) {
      try {
        final snap = await postRef.collection(sub).get();
        for (final doc in snap.docs) {
          try {
            await doc.reference.delete();
          } catch (_) {}
        }
      } catch (_) {}
    }

    // New Community images are inline Firestore data URLs and need no cleanup.
    // Keep best-effort cleanup for any legacy Storage-backed post.
    if (imageUrl.startsWith('gs://') ||
        imageUrl.startsWith('https://firebasestorage.googleapis.com/')) {
      try {
        await _storage.refFromURL(imageUrl).delete();
      } catch (_) {}
    }
  }

  Future<void> updatePostStatus(
    String postId,
    CommunityStatus status, {
    bool notifyMembers = false,
  }) async {
    await _postsRef.doc(postId).update({
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (notifyMembers) await _notifyInterestMembers(postId, status);
  }

  Future<void> _notifyInterestMembers(
    String postId,
    CommunityStatus status,
  ) async {
    try {
      final post = await _postsRef.doc(postId).get();
      final data = post.data();
      if (data == null) return;

      final postType = data['type'];
      final postCrop = data['cropName'] ?? '';
      final members = postType == 'demand'
          ? await _postsRef.doc(postId).collection('suppliers').get()
          : await _postsRef.doc(postId).collection('interests').get();

      final batch = _db.batch();
      for (final member in members.docs) {
        final id = _db.collection('users').doc('_').collection('_').doc().id;
        final item = CommunityActivity(
          id: id,
          ownerId: member.id,
          type: CommunityActivityType.statusChanged,
          actorId: _uid ?? '',
          actorName: data['authorName'] ?? 'Post owner',
          postId: postId,
          postCrop: postCrop,
          messageKey: status == CommunityStatus.fulfilled
              ? 'post_fulfilled'
              : 'post_reserved',
          params: {'crop': postCrop, 'status': status.value},
          deepLink: '/community',
          createdAt: DateTime.now(),
          read: false,
        );
        batch.set(
          _db
              .collection('users')
              .doc(member.id)
              .collection(_activityCollection)
              .doc(id),
          item.toMap(),
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[CommunityRepo] notify members failed: $e');
    }
  }

  Future<void> toggleLike(String postId) async {
    final uid = _uid;
    if (uid == null) return;

    final postRef = _postsRef.doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);

    await _db.runTransaction((txn) async {
      final likeDoc = await txn.get(likeRef);
      final postDoc = await txn.get(postRef);
      if (!postDoc.exists) return;

      if (likeDoc.exists) {
        txn.delete(likeRef);
        txn.update(postRef, {
          'likeCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        txn.set(likeRef, {
          'userId': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        txn.update(postRef, {
          'likeCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> likeDocStream(
    String postId,
    String userId,
  ) =>
      _postsRef.doc(postId).collection('likes').doc(userId).snapshots();

  Future<bool> sendInterest(String postId, {String note = ''}) async {
    final uid = _uid;
    if (uid == null) return false;

    final profile = await DataService().loadProfile();
    final userName = profile?.displayName ?? 'Interested farmer';
    final userPhoto = profile?.avatarUrl ?? '';
    final postRef = _postsRef.doc(postId);
    final interestRef = postRef.collection('interests').doc(uid);
    final post = await postRef.get();
    final data = post.data();
    if (data == null) return false;

    final existing = await interestRef.get();
    if (existing.exists) {
      await interestRef.update({
        'userName': userName,
        'userPhoto': userPhoto,
        'note': note,
        'status': CommunityMemberStatus.interested.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return false;
    }

    await interestRef.set(
      CommunityMember(
        userId: uid,
        userName: userName,
        userPhoto: userPhoto,
        note: note,
        postAuthorId: data['authorId'] ?? '',
        status: CommunityMemberStatus.interested,
        createdAt: DateTime.now(),
      ).toMap(),
    );

    await postRef.update({
      'interestedCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _pushActivity(
      ownerId: data['authorId'] ?? '',
      type: CommunityActivityType.interestNew,
      actorId: uid,
      actorName: userName,
      actorPhoto: userPhoto,
      postId: postId,
      postCrop: data['cropName'] ?? '',
      params: {'count': '${(data['interestedCount'] ?? 0) + 1}'},
    );
    return true;
  }

  Future<void> withdrawInterest(String postId) async {
    final uid = _uid;
    if (uid == null) return;
    final postRef = _postsRef.doc(postId);
    final interestRef = postRef.collection('interests').doc(uid);

    try {
      final existing = await interestRef.get();
      if (!existing.exists) return;
      await interestRef.delete();
      await postRef.update({
        'interestedCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[CommunityRepo] withdrawInterest failed: $e');
    }
  }

  Future<void> respondInterest(
    String postId,
    String userId,
    bool accept,
  ) async {
    final ownerId = _uid;
    if (ownerId == null) return;

    final postRef = _postsRef.doc(postId);
    final memberRef = postRef.collection('interests').doc(userId);
    final member = await memberRef.get();
    if (member.data() == null) return;
    final postData = (await postRef.get()).data() ?? const <String, dynamic>{};

    await memberRef.update({
      'status': accept
          ? CommunityMemberStatus.accepted.value
          : CommunityMemberStatus.declined.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _pushActivity(
      ownerId: userId,
      type: accept
          ? CommunityActivityType.interestAccepted
          : CommunityActivityType.interestDeclined,
      actorId: ownerId,
      actorName: postData['authorName'] ?? 'Post owner',
      postId: postId,
      postCrop: postData['cropName'] ?? '',
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> interestDocStream(
    String postId,
    String userId,
  ) =>
      _postsRef.doc(postId).collection('interests').doc(userId).snapshots();

  Stream<List<CommunityMember>> interestsStream(String postId) => _postsRef
      .doc(postId)
      .collection('interests')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(CommunityMember.fromFirestore).toList());

  Future<bool> sendSupply(String postId, {String note = ''}) async {
    final uid = _uid;
    if (uid == null) return false;

    final profile = await DataService().loadProfile();
    final userName = profile?.displayName ?? 'Supplier';
    final userPhoto = profile?.avatarUrl ?? '';
    final postRef = _postsRef.doc(postId);
    final supplierRef = postRef.collection('suppliers').doc(uid);
    final post = await postRef.get();
    final data = post.data();
    if (data == null) return false;

    final existing = await supplierRef.get();
    if (existing.exists) {
      await supplierRef.update({
        'userName': userName,
        'userPhoto': userPhoto,
        'note': note,
        'status': CommunityMemberStatus.interested.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return false;
    }

    await supplierRef.set(
      CommunityMember(
        userId: uid,
        userName: userName,
        userPhoto: userPhoto,
        note: note,
        postAuthorId: data['authorId'] ?? '',
        status: CommunityMemberStatus.interested,
        createdAt: DateTime.now(),
      ).toMap(),
    );

    await postRef.update({
      'supplierCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _pushActivity(
      ownerId: data['authorId'] ?? '',
      type: CommunityActivityType.supplierNew,
      actorId: uid,
      actorName: userName,
      actorPhoto: userPhoto,
      postId: postId,
      postCrop: data['cropName'] ?? '',
      params: {'count': '${(data['supplierCount'] ?? 0) + 1}'},
    );
    return true;
  }

  Future<void> withdrawSupply(String postId) async {
    final uid = _uid;
    if (uid == null) return;
    final postRef = _postsRef.doc(postId);
    final supplierRef = postRef.collection('suppliers').doc(uid);

    try {
      final existing = await supplierRef.get();
      if (!existing.exists) return;
      await supplierRef.delete();
      await postRef.update({
        'supplierCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[CommunityRepo] withdrawSupply failed: $e');
    }
  }

  Future<void> respondSupplier(
    String postId,
    String userId,
    bool accept,
  ) async {
    final ownerId = _uid;
    if (ownerId == null) return;

    final postRef = _postsRef.doc(postId);
    final memberRef = postRef.collection('suppliers').doc(userId);
    final member = await memberRef.get();
    if (member.data() == null) return;
    final postData = (await postRef.get()).data() ?? const <String, dynamic>{};

    await memberRef.update({
      'status': accept
          ? CommunityMemberStatus.accepted.value
          : CommunityMemberStatus.declined.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _pushActivity(
      ownerId: userId,
      type: accept
          ? CommunityActivityType.supplierAccepted
          : CommunityActivityType.supplierDeclined,
      actorId: ownerId,
      actorName: postData['authorName'] ?? 'Post owner',
      postId: postId,
      postCrop: postData['cropName'] ?? '',
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> supplyDocStream(
    String postId,
    String userId,
  ) =>
      _postsRef.doc(postId).collection('suppliers').doc(userId).snapshots();

  Stream<List<CommunityMember>> suppliersStream(String postId) => _postsRef
      .doc(postId)
      .collection('suppliers')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(CommunityMember.fromFirestore).toList());

  Future<void> addComment(String postId, String text) async {
    final uid = _uid;
    if (uid == null) return;

    final profile = await DataService().loadProfile();
    final authorName = profile?.displayName ?? 'Anonymous';
    final authorPhoto = profile?.avatarUrl ?? '';
    final postRef = _postsRef.doc(postId);
    final commentRef = postRef.collection('comments').doc();

    await commentRef.set(
      CommunityComment(
        id: commentRef.id,
        postId: postId,
        authorId: uid,
        authorName: authorName,
        authorPhoto: authorPhoto,
        text: text,
        createdAt: DateTime.now(),
      ).toMap(),
    );

    await postRef.update({
      'commentCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final data = (await postRef.get()).data();
    if (data != null) {
      await _pushActivity(
        ownerId: data['authorId'] ?? '',
        type: CommunityActivityType.comment,
        actorId: uid,
        actorName: authorName,
        actorPhoto: authorPhoto,
        postId: postId,
        postCrop: data['cropName'] ?? '',
        params: {'text': text},
      );
    }
  }

  Stream<List<CommunityComment>> commentsStream(String postId) => _postsRef
      .doc(postId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => CommunityComment.fromFirestore(doc, postId: postId))
          .toList());

  Future<void> deleteComment(String postId, String commentId) async {
    final uid = _uid;
    if (uid == null) return;
    final batch = _db.batch();
    batch.delete(_postsRef.doc(postId).collection('comments').doc(commentId));
    batch.update(_postsRef.doc(postId), {
      'commentCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> _pushActivity({
    required String ownerId,
    required CommunityActivityType type,
    required String postId,
    String actorId = '',
    String actorName = '',
    String actorPhoto = '',
    String postCrop = '',
    String postTitle = '',
    Map<String, String> params = const {},
  }) async {
    if (ownerId.isEmpty) return;
    final me = _uid ?? '';
    if (ownerId == me) return;

    try {
      final id = _db.collection('users').doc('_').collection('_').doc().id;
      final item = CommunityActivity(
        id: id,
        ownerId: ownerId,
        type: type,
        actorId: actorId,
        actorName: actorName,
        actorPhoto: actorPhoto,
        postId: postId,
        postCrop: postCrop,
        postTitle: postTitle,
        messageKey: '${type.value}_msg',
        params: params,
        deepLink: '/community',
        createdAt: DateTime.now(),
        read: false,
      );
      await _db
          .collection('users')
          .doc(ownerId)
          .collection(_activityCollection)
          .doc(id)
          .set(item.toMap());
    } catch (e) {
      debugPrint('[CommunityRepo] activity push failed: $e');
    }
  }

  /// Converts a compressed image into a small Firestore-safe data URL.
  ///
  /// This deliberately avoids Firebase Storage so Community photos work on the
  /// Spark plan without provisioning a Storage bucket.
  Future<String?> uploadImage({
    required String postId,
    required XFile imageFile,
  }) async {
    if (_uid == null) return null;

    try {
      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty || bytes.length > _maxInlineImageBytes) {
        debugPrint(
          '[CommunityRepo] Inline image skipped: ${bytes.length} bytes '
          '(limit $_maxInlineImageBytes)',
        );
        return null;
      }

      final suppliedMime = imageFile.mimeType;
      final mime = suppliedMime != null && suppliedMime.startsWith('image/')
          ? suppliedMime
          : 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('[CommunityRepo] Inline image encode failed: $e');
      return null;
    }
  }

  Future<XFile?> pickAndCompressImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      return await picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 50,
      );
    } catch (e) {
      debugPrint('[CommunityRepo] Image pick failed: $e');
      return null;
    }
  }

  Future<(String, String)> getUserStateDistrict() async {
    final profile = await DataService().loadProfile();
    final address = profile?.address;
    if (address == null) return ('', '');
    return (address.state ?? '', address.district ?? '');
  }

  Future<String> getUserDistrict() async {
    final (_, district) = await getUserStateDistrict();
    return district;
  }

  Future<List<FarmProfile>> getUserFarms() async {
    try {
      return await DataService().loadFarms();
    } catch (e) {
      debugPrint('[CommunityRepo] loadFarms failed: $e');
      return [];
    }
  }

  Future<List<CropRecord>> getActiveCrops(String farmId) async {
    try {
      final crops = await DataService().loadCrops(farmId);
      final active = crops.where((crop) => crop.isActive).toList()
        ..sort((a, b) => b.plantingDate.compareTo(a.plantingDate));
      return active;
    } catch (e) {
      debugPrint('[CommunityRepo] loadCrops failed: $e');
      return [];
    }
  }

  Future<Map<String, String>> getAuthorInfo(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'name': data['displayName'] ?? 'Anonymous',
          'photo': data['avatarUrl'] ?? '',
        };
      }
    } catch (_) {}
    return {'name': 'Anonymous', 'photo': ''};
  }
}
