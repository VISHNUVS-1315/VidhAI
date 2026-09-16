import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/data/models/notification_model.dart';
import 'package:vidhai/services/task_service.dart';
import 'package:vidhai/services/notification/notification_logic.dart';
import 'package:vidhai/services/notification/notification_settings_service.dart';
import 'package:vidhai/services/notification/notification_history_store.dart';

void main() {
  group('NotificationLogic.parseScheduleTime', () {
    test('parses 12-hour AM times', () {
      final result = NotificationLogic.parseScheduleTime('8:00 AM');
      expect(result, (8, 0));
    });

    test('parses 12:00 PM as noon', () {
      final result = NotificationLogic.parseScheduleTime('12:00 PM');
      expect(result, (12, 0));
    });

    test('parses 6:30 PM', () {
      final result = NotificationLogic.parseScheduleTime('6:30 PM');
      expect(result, (18, 30));
    });

    test('parses 12:00 AM as midnight', () {
      final result = NotificationLogic.parseScheduleTime('12:00 AM');
      expect(result, (0, 0));
    });

    test('parses 24h military time', () {
      final result = NotificationLogic.parseScheduleTime('14:30');
      expect(result, (14, 30));
    });

    test('returns null for empty string', () {
      expect(NotificationLogic.parseScheduleTime(''), isNull);
    });

    test('returns null for null', () {
      expect(NotificationLogic.parseScheduleTime(null), isNull);
    });

    test('returns null for garbage input', () {
      expect(NotificationLogic.parseScheduleTime('noon'), isNull);
    });
  });

  group('NotificationLogic.nextOccurrence', () {
    test('returns today when time is in the future', () {
      final now = DateTime(2026, 9, 15, 6, 0);
      final result = NotificationLogic.nextOccurrence(now, 8, 0);
      expect(result.day, 15);
      expect(result.hour, 8);
      expect(result.minute, 0);
    });

    test('returns tomorrow when time is in the past', () {
      final now = DateTime(2026, 9, 15, 10, 0);
      final result = NotificationLogic.nextOccurrence(now, 8, 0);
      expect(result.day, 16);
      expect(result.hour, 8);
    });

    test('returns today when within 1 minute of now', () {
      final now = DateTime(2026, 9, 15, 8, 0);
      final result = NotificationLogic.nextOccurrence(now, 8, 0);
      expect(result.day, 15);
    });
  });

  group('NotificationLogic.stableId', () {
    test('returns non-negative int', () {
      final id = NotificationLogic.stableId('test_seed');
      expect(id, greaterThanOrEqualTo(0));
    });

    test('is deterministic', () {
      final a = NotificationLogic.stableId('same_seed');
      final b = NotificationLogic.stableId('same_seed');
      expect(a, equals(b));
    });

    test('different seeds produce different ids', () {
      final a = NotificationLogic.stableId('seed_a');
      final b = NotificationLogic.stableId('seed_b');
      expect(a, isNot(equals(b)));
    });
  });

  group('NotificationLogic.taskReminderId', () {
    test('generates stable id from task content', () {
      final task1 = _makeTask('Check irrigation - Farm1', '8:00 AM', 0);
      final task2 = _makeTask('Check irrigation - Farm1', '8:00 AM', 0);
      expect(
          NotificationLogic.taskReminderId(task1),
          equals(NotificationLogic.taskReminderId(task2)));
    });

    test('different tasks produce different ids', () {
      final task1 = _makeTask('Check irrigation', '8:00 AM', 0);
      final task2 = _makeTask('Check pest', '10:00 AM', 0);
      expect(
          NotificationLogic.taskReminderId(task1),
          isNot(equals(NotificationLogic.taskReminderId(task2))));
    });
  });

  group('NotificationLogic.taskListFingerprint', () {
    test('same tasks produce same fingerprint', () {
      final List<FarmTask> tasks1 = [_makeTask('T1', '8:00 AM', 0), _makeTask('T2', '9:00 AM', 1)];
      final List<FarmTask> tasks2 = [_makeTask('T1', '8:00 AM', 0), _makeTask('T2', '9:00 AM', 1)];
      expect(NotificationLogic.taskListFingerprint(tasks1),
          equals(NotificationLogic.taskListFingerprint(tasks2)));
    });

    test('different tasks produce different fingerprint', () {
      final List<FarmTask> tasks1 = [_makeTask('T1', '8:00 AM', 0)];
      final List<FarmTask> tasks2 = [_makeTask('T2', '8:00 AM', 0)];
      expect(NotificationLogic.taskListFingerprint(tasks1),
          isNot(equals(NotificationLogic.taskListFingerprint(tasks2))));
    });

    test('completing a task changes fingerprint', () {
      final task = _makeTask('T1', '8:00 AM', 0);
      final List<FarmTask> tasks1 = [task];
      final List<FarmTask> tasks2 = [task.copyWith(completed: true)];
      expect(NotificationLogic.taskListFingerprint(tasks1),
          isNot(equals(NotificationLogic.taskListFingerprint(tasks2))));
    });

    test('ordering does not affect fingerprint', () {
      final List<FarmTask> tasks1 = [_makeTask('T1', '8:00 AM', 0), _makeTask('T2', '9:00 AM', 1)];
      final List<FarmTask> tasks2 = [_makeTask('T2', '9:00 AM', 1), _makeTask('T1', '8:00 AM', 0)];
      expect(NotificationLogic.taskListFingerprint(tasks1),
          equals(NotificationLogic.taskListFingerprint(tasks2)));
    });
  });

  group('NotificationLogic.shouldNotifyWeather', () {
    const thresholds = WeatherAlertThresholds();

    test('returns true when no previous signature', () {
      expect(
        NotificationLogic.shouldNotifyWeather(
          previousSignature: null,
          previousTime: null,
          newSignature: 'rain',
          now: DateTime.now(),
          thresholds: thresholds,
        ),
        isTrue,
      );
    });

    test('returns false when same signature within cooldown', () {
      final now = DateTime.now();
      expect(
        NotificationLogic.shouldNotifyWeather(
          previousSignature: 'rain',
          previousTime: now,
          newSignature: 'rain',
          now: now.add(const Duration(minutes: 30)),
          thresholds: thresholds,
        ),
        isFalse,
      );
    });

    test('returns true when same signature after cooldown', () {
      final now = DateTime.now();
      expect(
        NotificationLogic.shouldNotifyWeather(
          previousSignature: 'rain',
          previousTime: now,
          newSignature: 'rain',
          now: now.add(const Duration(hours: 7)),
          thresholds: thresholds,
        ),
        isTrue,
      );
    });

    test('returns true when signature changes', () {
      final now = DateTime.now();
      expect(
        NotificationLogic.shouldNotifyWeather(
          previousSignature: 'rain',
          previousTime: now,
          newSignature: 'heat',
          now: now.add(const Duration(minutes: 5)),
          thresholds: thresholds,
        ),
        isTrue,
      );
    });

    test('returns false when new signature is null (no alert)', () {
      expect(
        NotificationLogic.shouldNotifyWeather(
          previousSignature: 'rain',
          previousTime: DateTime.now().subtract(const Duration(hours: 1)),
          newSignature: null,
          now: DateTime.now(),
          thresholds: thresholds,
        ),
        isFalse,
      );
    });
  });

  group('NotificationLogic.deepLinkFor', () {
    test('task category maps to /tasks', () {
      expect(NotificationLogic.deepLinkFor(null, 'task'), '/tasks');
    });

    test('market category maps to /market-prices', () {
      expect(NotificationLogic.deepLinkFor(null, 'market'), '/market-prices');
    });

    test('welcome category maps to /main_shell', () {
      expect(NotificationLogic.deepLinkFor(null, 'welcome'), '/main_shell');
    });

    test('custom deepLink is used when provided', () {
      expect(NotificationLogic.deepLinkFor('/custom/route', 'task'), '/custom/route');
    });
  });

  group('NotificationHistoryStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('add persists and load retrieves', () async {
      final store = NotificationHistoryStore.instance;
      final n = _makeNotification('id1', 'Title', 'Body', 'task');
      await store.add(n);
      final list = await store.load();
      expect(list.length, 1);
      expect(list.first.id, 'id1');
    });

    test('deduplicates by id', () async {
      final store = NotificationHistoryStore.instance;
      final n1 = _makeNotification('id1', 'T1', 'B1', 'task');
      final n2 = _makeNotification('id1', 'T2', 'B2', 'task');
      await store.add(n1);
      await store.add(n2);
      final list = await store.load();
      expect(list.length, 1);
      expect(list.first.title, 'T2');
    });

    test('markAsRead works', () async {
      final store = NotificationHistoryStore.instance;
      await store.add(_makeNotification('id1', 'T', 'B', 'task'));
      await store.markAsRead('id1');
      final list = await store.load();
      expect(list.first.isRead, isTrue);
    });

    test('unreadCount returns correct count', () async {
      final store = NotificationHistoryStore.instance;
      await store.add(_makeNotification('id1', 'T1', 'B1', 'task'));
      await store.add(_makeNotification('id2', 'T2', 'B2', 'task'));
      await store.markAsRead('id1');
      expect(await store.unreadCount(), 1);
    });
  });

  group('NotificationSettingsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('all categories default to enabled', () async {
      final s = NotificationSettingsService();
      expect(await s.taskRemindersEnabled(), isTrue);
      expect(await s.weatherAlertsEnabled(), isTrue);
      expect(await s.marketUpdatesEnabled(), isTrue);
      expect(await s.generalNotificationsEnabled(), isTrue);
    });

    test('can disable and re-enable', () async {
      final s = NotificationSettingsService();
      await s.setTaskReminders(false);
      expect(await s.taskRemindersEnabled(), isFalse);
      await s.setTaskReminders(true);
      expect(await s.taskRemindersEnabled(), isTrue);
    });

    test('enable/disable only affects its own category', () async {
      final s = NotificationSettingsService();
      await s.setWeatherAlerts(false);
      expect(await s.taskRemindersEnabled(), isTrue);
      expect(await s.weatherAlertsEnabled(), isFalse);
    });
  });

  group('NotificationCategories', () {
    test('isValid accepts known categories', () {
      expect(NotificationCategories.isValid('task'), isTrue);
      expect(NotificationCategories.isValid('weather'), isTrue);
      expect(NotificationCategories.isValid('market'), isTrue);
      expect(NotificationCategories.isValid('welcome'), isTrue);
    });

    test('isValid rejects unknown categories', () {
      expect(NotificationCategories.isValid('unknown'), isFalse);
      expect(NotificationCategories.isValid(''), isFalse);
    });
  });

  group('NotificationChannels', () {
    test('channelFor maps task category to correct channel', () {
      expect(NotificationChannels.channelFor('task'), 'vidhai_tasks');
    });

    test('channelFor maps weather to vidhai_weather', () {
      expect(NotificationChannels.channelFor('weather'), 'vidhai_weather');
    });

    test('channelFor maps market to vidhai_market', () {
      expect(NotificationChannels.channelFor('market'), 'vidhai_market');
    });

    test('channelFor maps welcome to vidhai_welcome', () {
      expect(NotificationChannels.channelFor('welcome'), 'vidhai_welcome');
    });

    test('channelFor unknown defaults to vidhai_updates', () {
      expect(NotificationChannels.channelFor('unknown'), 'vidhai_updates');
    });
  });
}

FarmTask _makeTask(String title, String? scheduledTime, int index) {
  return FarmTask(
    id: 'task_${index}_${DateTime.now().millisecondsSinceEpoch}',
    farmName: 'Farm1',
    farmIndex: index,
    title: title,
    category: 'general',
    scheduledTime: scheduledTime,
    createdAt: DateTime.now(),
  );
}

NotificationModel _makeNotification(String id, String title, String message, String category) {
  return NotificationModel(
    id: id,
    title: title,
    message: message,
    category: category,
    createdAt: DateTime.now(),
  );
}
