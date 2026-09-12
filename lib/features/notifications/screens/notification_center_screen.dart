import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/notification_service.dart';
import 'package:vidhai/data/models/notification_model.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/locale/locale.dart';
import 'package:vidhai/core/widgets/vidhai_widgets.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
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

    final deepLinkRoute =
        NotificationService.getDeepLinkRoute(notification.deepLink);
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

  String _formatTimestamp(DateTime dateTime, AppLocalizations loc) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return loc.timeAgoJustNow;
    if (diff.inMinutes < 60) {
      return loc.timeAgoM.replaceAll('{count}', '${diff.inMinutes}');
    }
    if (diff.inHours < 24) {
      return loc.timeAgoH.replaceAll('{count}', '${diff.inHours}');
    }
    if (diff.inDays < 7) {
      return loc.timeAgoD.replaceAll('{count}', '${diff.inDays}');
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(directionalIcon(context, Icons.arrow_back_ios_new),
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          loc.notificationCenterTitle,
          style: TextStyle(
            color: colors.onBackground,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                loc.markAllAsRead,
                style: TextStyle(
                  color: colors.brandDeep,
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
          ? Center(
              child: CircularProgressIndicator(
                color: colors.brandDeep,
                strokeWidth: 2,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              color: colors.brandDeep,
              backgroundColor: colors.surface,
              child: _notifications.isEmpty
                  ? _buildEmptyState()
                  : _buildNotificationList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
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
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.borderColor,
                      ),
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      color: colors.onSurfaceMuted,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    loc.noNotificationsYet,
                    style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      loc.notificationsEmptyHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceMuted,
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
    final colors = VidhAIColorsX(context);
    final loc = AppLocalizations.of(context);
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(notification),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFEF5350).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child:
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF5350)),
      ),
      child: GestureDetector(
        onTap: () => _onNotificationTap(notification),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isRead
                ? colors.surface
                : colors.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: notification.isRead
                  ? colors.borderColor
                  : colors.brandDeep.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _categoryColor(notification.category)
                      .withValues(alpha: 0.12),
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
                            margin: const EdgeInsetsDirectional.only(end: 8),
                            decoration: BoxDecoration(
                              color: colors.brandDeep,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: colors.onBackground,
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
                        color: colors.onSurfaceMuted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTimestamp(notification.createdAt, loc),
                      style: TextStyle(
                        color: colors.onSurfaceMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                directionalIcon(context, Icons.chevron_right_rounded),
                color: colors.onSurfaceMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
