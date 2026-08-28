import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/notification_service.dart';
import 'package:vidhai/data/models/notification_model.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final DataService _dataService = DataService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final notifications = await _dataService.loadNotifications();
    if (mounted) {
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    await _dataService.markAllNotificationsRead();
    await _loadNotifications();
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (!notification.isRead) {
      await _dataService.markNotificationRead(notification.id);
      await _loadNotifications();
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    await _dataService.deleteNotification(notification.id);
    await _loadNotifications();
  }

  void _onNotificationTap(NotificationModel notification) async {
    await _markAsRead(notification);
    if (!mounted) return;

    final deepLinkRoute = NotificationService.getDeepLinkRoute(notification.deepLink);
    Navigator.of(context).pop();

    if (deepLinkRoute != null && mounted) {
      Navigator.of(context).pushNamed(deepLinkRoute);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'weather':
        return Icons.cloud;
      case 'market':
        return Icons.trending_up;
      case 'task':
        return Icons.task_alt;
      case 'alert':
        return Icons.warning;
      case 'recommendation':
        return Icons.auto_awesome;
      default:
        return Icons.notifications;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'weather':
        return const Color(0xFF42A5F5);
      case 'market':
        return const Color(0xFFFFA726);
      case 'task':
        return const Color(0xFF66BB6A);
      case 'alert':
        return const Color(0xFFEF5350);
      case 'recommendation':
        return const Color(0xFFAB47BC);
      default:
        return const Color(0xFF78909C);
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1A),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Notification Center',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all as read',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4CAF50),
                strokeWidth: 2,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              color: const Color(0xFF4CAF50),
              backgroundColor: const Color(0xFF111827),
              child: _notifications.isEmpty
                  ? _buildEmptyState()
                  : _buildNotificationList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white.withValues(alpha: 0.15),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Weather alerts, market updates, and AI recommendations will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationItem(notification);
      },
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(notification),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFEF5350).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350)),
      ),
      child: GestureDetector(
        onTap: () => _onNotificationTap(notification),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isRead
                ? const Color(0xFF111827)
                : const Color(0xFF111827).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: notification.isRead
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFF4CAF50).withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _categoryColor(notification.category).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _categoryIcon(notification.category),
                  color: _categoryColor(notification.category),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!notification.isRead)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTimestamp(notification.createdAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.1),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
