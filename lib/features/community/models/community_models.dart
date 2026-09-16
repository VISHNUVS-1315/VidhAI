import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  final String postId;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final List<String> imageUrls;
  final String category;
  final String district;
  final String state;
  final String crop;
  final String cropStage;
  final double? quantityKg;
  final double? expectedPricePerKg;
  final DateTime? expectedHarvestDate;
  final DateTime? requiredByDate;
  final String buyerType;
  final String status;
  final int interestedCount;
  final int likes;
  final List<String> likedBy;
  final int commentCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isAIAssisted;

  const CommunityPost({
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar = '',
    required this.content,
    this.imageUrls = const [],
    this.category = 'general',
    this.district = '',
    this.state = '',
    this.crop = '',
    this.cropStage = '',
    this.quantityKg,
    this.expectedPricePerKg,
    this.expectedHarvestDate,
    this.requiredByDate,
    this.buyerType = '',
    this.status = 'open',
    this.interestedCount = 0,
    this.likes = 0,
    this.likedBy = const [],
    this.commentCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isAIAssisted = false,
  });

  factory CommunityPost.fromMap(Map<String, dynamic> map) {
    double? asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    return CommunityPost(
      postId: map['postId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Anonymous',
      authorAvatar: map['authorAvatar'] ?? '',
      content: map['content'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      category: map['category'] ?? 'general',
      district: map['district'] ?? '',
      state: map['state'] ?? '',
      crop: map['crop'] ?? '',
      cropStage: map['cropStage'] ?? '',
      quantityKg: asDouble(map['quantityKg']),
      expectedPricePerKg: asDouble(map['expectedPricePerKg']),
      expectedHarvestDate:
          (map['expectedHarvestDate'] as Timestamp?)?.toDate(),
      requiredByDate: (map['requiredByDate'] as Timestamp?)?.toDate(),
      buyerType: map['buyerType'] ?? '',
      status: map['status'] ?? 'open',
      interestedCount: map['interestedCount'] ?? 0,
      likes: map['likes'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      commentCount: map['commentCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      isAIAssisted: map['isAIAssisted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'imageUrls': imageUrls,
      'category': category,
      'district': district,
      'state': state,
      'crop': crop,
      'cropStage': cropStage,
      'quantityKg': quantityKg,
      'expectedPricePerKg': expectedPricePerKg,
      'expectedHarvestDate': expectedHarvestDate == null
          ? null
          : Timestamp.fromDate(expectedHarvestDate!),
      'requiredByDate':
          requiredByDate == null ? null : Timestamp.fromDate(requiredByDate!),
      'buyerType': buyerType,
      'status': status,
      'interestedCount': interestedCount,
      'likes': likes,
      'likedBy': likedBy,
      'commentCount': commentCount,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isAIAssisted': isAIAssisted,
    };
  }

  CommunityPost copyWith({
    String? content,
    int? likes,
    List<String>? likedBy,
    int? commentCount,
    int? interestedCount,
    String? status,
  }) {
    return CommunityPost(
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content ?? this.content,
      imageUrls: imageUrls,
      category: category,
      district: district,
      state: state,
      crop: crop,
      cropStage: cropStage,
      quantityKg: quantityKg,
      expectedPricePerKg: expectedPricePerKg,
      expectedHarvestDate: expectedHarvestDate,
      requiredByDate: requiredByDate,
      buyerType: buyerType,
      status: status ?? this.status,
      interestedCount: interestedCount ?? this.interestedCount,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isAIAssisted: isAIAssisted,
    );
  }

  static const List<String> categories = [
    'general',
    'problem',
    'experience',
    'available_soon',
    'demand',
  ];
}

class CommunityComment {
  final String commentId;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final DateTime createdAt;

  const CommunityComment({
    required this.commentId,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar = '',
    required this.content,
    required this.createdAt,
  });

  factory CommunityComment.fromMap(Map<String, dynamic> map) {
    return CommunityComment(
      commentId: map['commentId'] ?? '',
      postId: map['postId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Anonymous',
      authorAvatar: map['authorAvatar'] ?? '',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
