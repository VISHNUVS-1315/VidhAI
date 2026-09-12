class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String category; // weather, market, task, alert, recommendation
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;
  final String? deepLink;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    this.isRead = false,
    required this.createdAt,
    this.data,
    this.deepLink,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'category': category,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
        'data': data,
        'deepLink': deepLink,
      };

  factory NotificationModel.fromMap(Map<String, dynamic> m) =>
      NotificationModel(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        message: m['message'] ?? '',
        category: m['category'] ?? 'alert',
        isRead: m['isRead'] ?? false,
        createdAt: m['createdAt'] != null
            ? DateTime.parse(m['createdAt'])
            : DateTime.now(),
        data: m['data'],
        deepLink: m['deepLink'],
      );

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        title: title,
        message: message,
        category: category,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        data: data,
        deepLink: deepLink,
      );
}
