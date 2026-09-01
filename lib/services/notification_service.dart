import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/formatters.dart';
import '../models/expense.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? localNotifications})
      : _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _localNotifications;
  bool _initialized = false;

  static const int dailyReminderNotificationId = 1001;
  static const int budgetAlertNotificationId = 1002;
  static const int largeExpenseNotificationId = 1003;
  static const int spendingInsightNotificationId = 1004;

  static const String channelId = 'smartspend_alerts';
  static const String channelName = 'SmartSpend Alerts';
  static const String channelDescription =
      'Notifications for budgets, daily reminders, and spending insights';

  static const NotificationDetails _defaultNotificationDetails =
      NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
    } catch (_) {
      // Gracefully handle if already initialized or in test environment
    }

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    try {
      await _localNotifications.initialize(settings: initializationSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService initialization skipped/failed: $e');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final granted =
            await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }

      final iosImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return false;
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await initialize();
    // Always cancel existing reminder first to prevent duplicate scheduled alarms
    await cancelDailyReminder();

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _localNotifications.zonedSchedule(
        id: dailyReminderNotificationId,
        title: 'Expense Reminder',
        body: "Don't forget to record today's expenses and review your budget.",
        scheduledDate: scheduledDate,
        notificationDetails: _defaultNotificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Error scheduling daily reminder: $e');
    }
  }

  Future<void> cancelDailyReminder() async {
    try {
      await _localNotifications.cancel(id: dailyReminderNotificationId);
    } catch (e) {
      debugPrint('Error canceling daily reminder: $e');
    }
  }

  Future<void> showBudgetAlert({
    required String title,
    required String body,
  }) async {
    await initialize();
    try {
      await _localNotifications.show(
        id: budgetAlertNotificationId,
        title: title,
        body: body,
        notificationDetails: _defaultNotificationDetails,
      );
    } catch (e) {
      debugPrint('Error displaying budget alert: $e');
    }
  }

  Future<void> showLargeExpenseAlert({
    required String title,
    required String body,
  }) async {
    await initialize();
    try {
      await _localNotifications.show(
        id: largeExpenseNotificationId,
        title: title,
        body: body,
        notificationDetails: _defaultNotificationDetails,
      );
    } catch (e) {
      debugPrint('Error displaying large expense alert: $e');
    }
  }

  Future<void> showInsightAlert({
    required String title,
    required String body,
  }) async {
    await initialize();
    try {
      await _localNotifications.show(
        id: spendingInsightNotificationId,
        title: title,
        body: body,
        notificationDetails: _defaultNotificationDetails,
      );
    } catch (e) {
      debugPrint('Error displaying spending insight alert: $e');
    }
  }

  static String generateInsightMessage(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return "Start recording expenses to track spending patterns and trends.";
    }

    final now = DateTime.now();
    final todayDebits = expenses
        .where((e) =>
            e.type == ExpenseType.debit &&
            e.date != null &&
            e.date!.year == now.year &&
            e.date!.month == now.month &&
            e.date!.day == now.day)
        .toList();
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayDebits = expenses
        .where((e) =>
            e.type == ExpenseType.debit &&
            e.date != null &&
            e.date!.year == yesterday.year &&
            e.date!.month == yesterday.month &&
            e.date!.day == yesterday.day)
        .toList();

    final todayTotal = todayDebits.fold<int>(0, (sum, e) => sum + e.amount);
    final yesterdayTotal =
        yesterdayDebits.fold<int>(0, (sum, e) => sum + e.amount);

    if (todayTotal > 0 && yesterdayTotal > 0) {
      if (todayTotal < yesterdayTotal) {
        final percentDiff =
            (((yesterdayTotal - todayTotal) / yesterdayTotal) * 100).round();
        return 'You spent ${formatMinorUnits(todayTotal)} today, which is $percentDiff% less than yesterday.';
      } else if (todayTotal > yesterdayTotal) {
        final percentDiff =
            (((todayTotal - yesterdayTotal) / yesterdayTotal) * 100).round();
        return 'You spent ${formatMinorUnits(todayTotal)} today, which is $percentDiff% more than yesterday.';
      } else {
        return 'You spent ${formatMinorUnits(todayTotal)} today, matching your spending from yesterday.';
      }
    }

    if (todayTotal > 0) {
      final txCount = todayDebits.length;
      return 'You spent ${formatMinorUnits(todayTotal)} today across $txCount transaction${txCount == 1 ? '' : 's'}.';
    }

    final currentMonthDebits = expenses
        .where((e) =>
            e.type == ExpenseType.debit &&
            e.date != null &&
            e.date!.year == now.year &&
            e.date!.month == now.month)
        .toList();

    if (currentMonthDebits.isNotEmpty) {
      final categoryTotals = <String, int>{};
      for (final e in currentMonthDebits) {
        final cat = e.category ?? 'General';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      }
      final topCategory = categoryTotals.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      return '${topCategory.key} is your highest spending category this month at ${formatMinorUnits(topCategory.value)}.';
    }

    final allDebits = expenses.where((e) => e.type == ExpenseType.debit).toList();
    if (allDebits.isNotEmpty) {
      final categoryTotals = <String, int>{};
      for (final e in allDebits) {
        final cat = e.category ?? 'General';
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      }
      final topCategory = categoryTotals.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      return '${topCategory.key} is your highest spending category at ${formatMinorUnits(topCategory.value)}.';
    }

    return 'Keep recording your daily expenses to see personalized insights!';
  }

  Future<void> showDynamicInsightAlert(List<Expense> expenses) async {
    final body = generateInsightMessage(expenses);
    await showInsightAlert(
      title: 'Your Spending Insight',
      body: body,
    );
  }

  Future<void> cancelAll() async {
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('Error canceling all notifications: $e');
    }
  }
}
