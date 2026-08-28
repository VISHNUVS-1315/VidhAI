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
    this.likes = 0,
    this.likedBy = const [],
    this.commentCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isAIAssisted = false,
  });

  factory CommunityPost.fromMap(Map<String, dynamic> map) {
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
    'crops',
    'pest_control',
    'irrigation',
    'market_prices',
    'equipment',
    'organic',
    'weather',
    'government_schemes',
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
