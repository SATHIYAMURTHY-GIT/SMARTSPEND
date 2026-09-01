import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/models/expense.dart';
import 'package:smartspend/models/notification_preferences.dart';
import 'package:smartspend/providers/notification_provider.dart';
import 'package:smartspend/repositories/notification_repository.dart';
import 'package:smartspend/screens/profile/notification_settings_screen.dart';
import 'package:smartspend/services/notification_service.dart';

class FakeNotificationRepository extends NotificationRepository {
  NotificationPreferences _prefs = const NotificationPreferences();

  NotificationPreferences get currentPreferences => _prefs;

  @override
  Future<NotificationPreferences> getPreferences() async => _prefs;

  @override
  Stream<NotificationPreferences> watchPreferences() async* {
    yield _prefs;
  }

  @override
  Future<void> updatePreferences(NotificationPreferences preferences) async {
    _prefs = preferences;
  }
}

class FakeNotificationService extends NotificationService {
  int scheduledDailyReminderCount = 0;
  int canceledDailyReminderCount = 0;
  int? lastScheduledHour;
  int? lastScheduledMinute;
  final List<String> shownAlerts = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    scheduledDailyReminderCount++;
    lastScheduledHour = hour;
    lastScheduledMinute = minute;
  }

  @override
  Future<void> cancelDailyReminder() async {
    canceledDailyReminderCount++;
  }

  @override
  Future<void> showBudgetAlert({
    required String title,
    required String body,
  }) async {
    shownAlerts.add('$title: $body');
  }

  @override
  Future<void> showLargeExpenseAlert({
    required String title,
    required String body,
  }) async {
    shownAlerts.add('$title: $body');
  }

  @override
  Future<void> showInsightAlert({
    required String title,
    required String body,
  }) async {
    shownAlerts.add('$title: $body');
  }

  @override
  Future<void> cancelAll() async {
    canceledDailyReminderCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationPreferences Model', () {
    test('default preferences have expected initial values', () {
      const prefs = NotificationPreferences();
      expect(prefs.budgetAlertsEnabled, isTrue);
      expect(prefs.expenseRemindersEnabled, isFalse);
      expect(prefs.reminderHour, 20);
      expect(prefs.reminderMinute, 0);
      expect(prefs.spendingInsightsEnabled, isTrue);
      expect(prefs.largeExpenseAlertsEnabled, isFalse);
      expect(prefs.largeExpenseThresholdMinorUnits, 500000);
    });

    test('toFirestore and fromFirestore serialize correctly', () {
      const prefs = NotificationPreferences(
        budgetAlertsEnabled: false,
        expenseRemindersEnabled: true,
        reminderHour: 9,
        reminderMinute: 30,
        spendingInsightsEnabled: false,
        largeExpenseAlertsEnabled: true,
        largeExpenseThresholdMinorUnits: 1000000,
      );

      final map = prefs.toFirestore();
      final reconstructed = NotificationPreferences.fromFirestore(map);

      expect(reconstructed.budgetAlertsEnabled, isFalse);
      expect(reconstructed.expenseRemindersEnabled, isTrue);
      expect(reconstructed.reminderHour, 9);
      expect(reconstructed.reminderMinute, 30);
      expect(reconstructed.spendingInsightsEnabled, isFalse);
      expect(reconstructed.largeExpenseAlertsEnabled, isTrue);
      expect(reconstructed.largeExpenseThresholdMinorUnits, 1000000);
    });
  });

  group('NotificationSettingsScreen UI & Interactions', () {
    testWidgets('renders all 4 preference switches and configuration tiles', (tester) async {
      final fakeRepo = FakeNotificationRepository();
      final fakeService = FakeNotificationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(fakeRepo),
            notificationServiceProvider.overrideWithValue(fakeService),
            notificationPreferencesProvider.overrideWith(
              (ref) => Stream.value(const NotificationPreferences(
                budgetAlertsEnabled: true,
                expenseRemindersEnabled: false,
                reminderHour: 20,
                reminderMinute: 0,
                spendingInsightsEnabled: true,
                largeExpenseAlertsEnabled: false,
                largeExpenseThresholdMinorUnits: 500000,
              )),
            ),
          ],
          child: const MaterialApp(
            home: NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 4 switches are rendered
      expect(find.text('Budget alerts'), findsOneWidget);
      expect(find.text('Expense reminders'), findsOneWidget);
      expect(find.text('Spending insights'), findsOneWidget);
      expect(find.text('Large expense alerts'), findsOneWidget);

      // Verify configuration tiles
      expect(find.text('Reminder time'), findsOneWidget);
      expect(find.text('8:00 PM'), findsOneWidget);
      expect(find.text('Large expense threshold'), findsOneWidget);
      expect(find.text('₹5000.00'), findsOneWidget);
    });

    testWidgets('toggling expense reminders schedules daily reminder and updates repo', (tester) async {
      final fakeRepo = FakeNotificationRepository();
      final fakeService = FakeNotificationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(fakeRepo),
            notificationServiceProvider.overrideWithValue(fakeService),
            notificationPreferencesProvider.overrideWith(
              (ref) => Stream.value(const NotificationPreferences(
                expenseRemindersEnabled: false,
                reminderHour: 20,
                reminderMinute: 0,
              )),
            ),
          ],
          child: const MaterialApp(
            home: NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find switch for expense reminders and toggle it
      final expenseReminderSwitch = find.ancestor(
        of: find.text('Expense reminders'),
        matching: find.byType(SwitchListTile),
      );
      await tester.tap(expenseReminderSwitch);
      await tester.pumpAndSettle();

      expect(fakeRepo.currentPreferences.expenseRemindersEnabled, isTrue);
      expect(fakeService.scheduledDailyReminderCount, 1);
      expect(fakeService.lastScheduledHour, 20);
      expect(fakeService.lastScheduledMinute, 0);
    });

    testWidgets('disabling expense reminders cancels scheduled reminder', (tester) async {
      final fakeRepo = FakeNotificationRepository();
      fakeRepo._prefs = const NotificationPreferences(
        expenseRemindersEnabled: true,
      );
      final fakeService = FakeNotificationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(fakeRepo),
            notificationServiceProvider.overrideWithValue(fakeService),
            notificationPreferencesProvider.overrideWith(
              (ref) => Stream.value(const NotificationPreferences(
                expenseRemindersEnabled: true,
              )),
            ),
          ],
          child: const MaterialApp(
            home: NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expenseReminderSwitch = find.ancestor(
        of: find.text('Expense reminders'),
        matching: find.byType(SwitchListTile),
      );
      await tester.tap(expenseReminderSwitch);
      await tester.pumpAndSettle();

      expect(fakeRepo.currentPreferences.expenseRemindersEnabled, isFalse);
      expect(fakeService.canceledDailyReminderCount, 1);
    });

    testWidgets('NotificationSettingsScreen has no development tester UI', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(FakeNotificationRepository()),
            notificationServiceProvider.overrideWithValue(FakeNotificationService()),
            notificationPreferencesProvider.overrideWith(
              (ref) => Stream.value(const NotificationPreferences()),
            ),
          ],
          child: const MaterialApp(
            home: NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Send test notification'), findsNothing);
      expect(find.text('Diagnostics & Testing'), findsNothing);
    });
  });

  group('NotificationService Dynamic Insights', () {
    Expense makeExpense({
      required String id,
      required int amount,
      required DateTime date,
      required String category,
    }) {
      return Expense(
        id: id,
        userId: 'test_user',
        amount: amount,
        type: ExpenseType.debit,
        category: category,
        merchant: null,
        description: null,
        date: date,
        paymentMethod: null,
        receiptUrl: null,
        createdAt: date,
        updatedAt: date,
      );
    }

    test('generateInsightMessage produces comparison insight when yesterday and today data exist', () {
      final now = DateTime.now();
      final expenses = [
        makeExpense(
          id: '1',
          amount: 45000,
          date: now,
          category: 'Food',
        ),
        makeExpense(
          id: '2',
          amount: 55000,
          date: now.subtract(const Duration(days: 1)),
          category: 'Food',
        ),
      ];

      final insight = NotificationService.generateInsightMessage(expenses);
      expect(insight, contains('less than yesterday'));
      expect(insight, contains('₹450.00'));
    });

    test('generateInsightMessage produces top category insight when month debits exist', () {
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 2));
      final expenses = [
        makeExpense(
          id: '1',
          amount: 250000,
          date: pastDate,
          category: 'Rent',
        ),
        makeExpense(
          id: '2',
          amount: 50000,
          date: pastDate,
          category: 'Groceries',
        ),
      ];

      final insight = NotificationService.generateInsightMessage(expenses);
      expect(insight, contains('Rent is your highest spending category'));
      expect(insight, contains('₹2500.00'));
    });
  });
}
