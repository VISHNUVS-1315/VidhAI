import 'package:cloud_firestore/cloud_firestore.dart';

/// Post categories shown in the Community (single `community_posts` collection).
enum CommunityPostType {
  experience('experience'),
  harvest('harvest'),
  demand('demand');

  const CommunityPostType(this.value);
  final String value;

  factory CommunityPostType.fromValue(String? v) {
    switch (v) {
      case 'harvest':
        return CommunityPostType.harvest;
      case 'demand':
        return CommunityPostType.demand;
      default:
        return CommunityPostType.experience;
    }
  }
}

/// Lifecycle status of a community post.
enum CommunityStatus {
  active('active'),
  reserved('reserved'),
  fulfilled('fulfilled'),
  closed('closed');

  const CommunityStatus(this.value);
  final String value;

  factory CommunityStatus.fromValue(String? v) {
    switch (v) {
      case 'reserved':
        return CommunityStatus.reserved;
      case 'fulfilled':
        return CommunityStatus.fulfilled;
      case 'closed':
        return CommunityStatus.closed;
      default:
        return CommunityStatus.active;
    }
  }
}

/// Status of an interest/supplier request on a harvest or demand post.
enum CommunityMemberStatus {
  interested('interested'),
  accepted('accepted'),
  declined('declined');

  const CommunityMemberStatus(this.value);
  final String value;

  factory CommunityMemberStatus.fromValue(String? v) {
    switch (v) {
      case 'accepted':
        return CommunityMemberStatus.accepted;
      case 'declined':
        return CommunityMemberStatus.declined;
      default:
        return CommunityMemberStatus.interested;
    }
  }
}

/// Unified post stored in `community_posts`. Section-specific fields are kept
/// optional so every category shares the same document schema.
class CommunityPost {
  final String id;
  final String authorId;
  final String authorName;
  final String authorPhoto;

  final CommunityPostType type;
  final CommunityStatus status;

  final String state;
  final String district;
  final String farmId;
  final String farmName;
  final String cropId;
  final String cropName;

  final String imageUrl;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Experience
  final String title;
  final String experienceText;
  final int likeCount;
  final int commentCount;

  // Harvest
  final double? quantityKg;
  final DateTime? harvestDate;
  final double? askingPricePerKg;
  final double? marketReferencePerKg;
  final double? suggestedMinPrice;
  final double? suggestedMaxPrice;
  final String? priceRiskLevel;
  final int interestedCount;

  // Demand
  final DateTime? requiredDate;
  final double? targetPricePerKg;
  final int supplierCount;

  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhoto = '',
    required this.type,
    this.status = CommunityStatus.active,
    this.state = '',
    this.district = '',
    this.farmId = '',
    this.farmName = '',
    this.cropId = '',
    this.cropName = '',
    this.imageUrl = '',
    this.description = '',
    required this.createdAt,
    this.updatedAt,
    this.title = '',
    this.experienceText = '',
    this.likeCount = 0,
    this.commentCount = 0,
    this.quantityKg,
    this.harvestDate,
    this.askingPricePerKg,
    this.marketReferencePerKg,
    this.suggestedMinPrice,
    this.suggestedMaxPrice,
    this.priceRiskLevel,
    this.interestedCount = 0,
    this.requiredDate,
    this.targetPricePerKg,
    this.supplierCount = 0,
  });

  bool get isHarvest => type == CommunityPostType.harvest;
  bool get isDemand => type == CommunityPostType.demand;
  bool get isExperience => type == CommunityPostType.experience;

  /// Avg of current market (AGMARKNET) price used as the reference.
  double get referencePerKg => marketReferencePerKg ?? suggestedMinPrice ?? 0;

  int get daysUntilHarvest {
    if (harvestDate == null) return -1;
    return harvestDate!.difference(DateTime.now()).inDays;
  }

  bool get isExpiredHarvest =>
      harvestDate != null && harvestDate!.isBefore(DateTime.now());

  factory CommunityPost.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return CommunityPost.fromMap(map, id: doc.id);
  }

  factory CommunityPost.fromMap(Map<String, dynamic> m, {String? id}) {
    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return CommunityPost(
      id: id ?? m['id'] ?? '',
      authorId: m['authorId'] ?? '',
      authorName: m['authorName'] ?? 'Anonymous',
      authorPhoto: m['authorPhoto'] ?? '',
      type: CommunityPostType.fromValue(m['type']),
      status: CommunityStatus.fromValue(m['status']),
      state: m['state'] ?? '',
      district: m['district'] ?? '',
      farmId: m['farmId'] ?? '',
      farmName: m['farmName'] ?? '',
      cropId: m['cropId'] ?? '',
      cropName: m['cropName'] ?? '',
      imageUrl: m['imageUrl'] ?? '',
      description: m['description'] ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      title: m['title'] ?? '',
      experienceText: m['experienceText'] ?? '',
      likeCount: m['likeCount'] ?? 0,
      commentCount: m['commentCount'] ?? 0,
      quantityKg: asDouble(m['quantityKg']),
      harvestDate: (m['harvestDate'] as Timestamp?)?.toDate(),
      askingPricePerKg: asDouble(m['askingPricePerKg']),
      marketReferencePerKg: asDouble(m['marketReferencePerKg']),
      suggestedMinPrice: asDouble(m['suggestedMinPrice']),
      suggestedMaxPrice: asDouble(m['suggestedMaxPrice']),
      priceRiskLevel: m['priceRiskLevel']?.toString(),
      interestedCount: m['interestedCount'] ?? 0,
      requiredDate: (m['requiredDate'] as Timestamp?)?.toDate(),
      targetPricePerKg: asDouble(m['targetPricePerKg']),
      supplierCount: m['supplierCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'type': type.value,
      'status': status.value,
      'state': state,
      'district': district,
      'farmId': farmId,
      'farmName': farmName,
      'cropId': cropId,
      'cropName': cropName,
      'imageUrl': imageUrl,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'title': title,
      'experienceText': experienceText,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'quantityKg': quantityKg,
      'harvestDate':
          harvestDate != null ? Timestamp.fromDate(harvestDate!) : null,
      'askingPricePerKg': askingPricePerKg,
      'marketReferencePerKg': marketReferencePerKg,
      'suggestedMinPrice': suggestedMinPrice,
      'suggestedMaxPrice': suggestedMaxPrice,
      'priceRiskLevel': priceRiskLevel,
      'interestedCount': interestedCount,
      'requiredDate':
          requiredDate != null ? Timestamp.fromDate(requiredDate!) : null,
      'targetPricePerKg': targetPricePerKg,
      'supplierCount': supplierCount,
    };
  }

  Map<String, dynamic> toCleanUpdateMap() {
    final map = toMap()..remove('id')..remove('createdAt')
      ..remove('updatedAt');
    return map;
  }
}

class CommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorPhoto;
  final String text;
  final DateTime createdAt;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorPhoto = '',
    required this.text,
    required this.createdAt,
  });

  factory CommunityComment.fromFirestore(
      DocumentSnapshot doc, {String? postId}) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    return CommunityComment(
      id: doc.id,
      postId: postId ?? m['postId'] ?? '',
      authorId: m['authorId'] ?? '',
      authorName: m['authorName'] ?? 'Anonymous',
      authorPhoto: m['authorPhoto'] ?? '',
      text: m['text'] ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// A farmer who expressed interest on a harvest post (or offered supply on a
/// demand post). `status` reflects the owner's accept/decline decision.
class CommunityMember {
  final String userId;
  final String userName;
  final String userPhoto;
  final String note;
  final String postAuthorId;
  final CommunityMemberStatus status;
  final DateTime createdAt;

  const CommunityMember({
    required this.userId,
    required this.userName,
    this.userPhoto = '',
    this.note = '',
    this.postAuthorId = '',
    this.status = CommunityMemberStatus.interested,
    required this.createdAt,
  });

  factory CommunityMember.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    return CommunityMember(
      userId: doc.id,
      userName: m['userName'] ?? 'Anonymous',
      userPhoto: m['userPhoto'] ?? '',
      note: m['note'] ?? '',
      postAuthorId: m['postAuthorId'] ?? '',
      status: CommunityMemberStatus.fromValue(m['status']),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'note': note,
      'postAuthorId': postAuthorId,
      'status': status.value,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

enum CommunityActivityType {
  interestNew('interest_new'),
  interestAccepted('interest_accepted'),
  interestDeclined('interest_declined'),
  supplierNew('supplier_new'),
  supplierAccepted('supplier_accepted'),
  supplierDeclined('supplier_declined'),
  comment('comment'),
  statusChanged('status_changed');

  const CommunityActivityType(this.value);
  final String value;

  factory CommunityActivityType.fromValue(String? v) {
    switch (v) {
      case 'interest_accepted':
        return CommunityActivityType.interestAccepted;
      case 'interest_declined':
        return CommunityActivityType.interestDeclined;
      case 'supplier_new':
        return CommunityActivityType.supplierNew;
      case 'supplier_accepted':
        return CommunityActivityType.supplierAccepted;
      case 'supplier_declined':
        return CommunityActivityType.supplierDeclined;
      case 'comment':
        return CommunityActivityType.comment;
      case 'status_changed':
        return CommunityActivityType.statusChanged;
      default:
        return CommunityActivityType.interestNew;
    }
  }
}

/// In-app activity item, stored under `users/{uid}/community_activity`.
/// Firestore is the source of truth; FCM push is only delivery.
class CommunityActivity {
  final String id;
  final String ownerId;
  final CommunityActivityType type;
  final String actorId;
  final String actorName;
  final String actorPhoto;
  final String postId;
  final String postTitle;
  final String postCrop;
  final String messageKey;
  final Map<String, String> params;
  final String deepLink;
  final DateTime createdAt;
  final bool read;

  const CommunityActivity({
    required this.id,
    required this.ownerId,
    required this.type,
    this.actorId = '',
    this.actorName = '',
    this.actorPhoto = '',
    required this.postId,
    this.postTitle = '',
    this.postCrop = '',
    this.messageKey = '',
    this.params = const {},
    this.deepLink = '/community',
    required this.createdAt,
    this.read = false,
  });

  factory CommunityActivity.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    return CommunityActivity(
      id: doc.id,
      ownerId: m['ownerId'] ?? '',
      type: CommunityActivityType.fromValue(m['type']),
      actorId: m['actorId'] ?? '',
      actorName: m['actorName'] ?? '',
      actorPhoto: m['actorPhoto'] ?? '',
      postId: m['postId'] ?? '',
      postTitle: m['postTitle'] ?? '',
      postCrop: m['postCrop'] ?? '',
      messageKey: m['messageKey'] ?? '',
      params: Map<String, String>.from(m['params'] ?? const {}),
      deepLink: m['deepLink'] ?? '/community',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: m['read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'type': type.value,
      'actorId': actorId,
      'actorName': actorName,
      'actorPhoto': actorPhoto,
      'postId': postId,
      'postTitle': postTitle,
      'postCrop': postCrop,
      'messageKey': messageKey,
      'params': params,
      'deepLink': deepLink,
      'createdAt': Timestamp.fromDate(createdAt),
      'read': read,
    };
  }
}