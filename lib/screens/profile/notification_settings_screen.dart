import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../models/notification_preferences.dart';
import '../../providers/notification_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _isUpdating = false;

  Future<void> _updatePreferences(
    NotificationPreferences current,
    NotificationPreferences updated,
  ) async {
    setState(() => _isUpdating = true);
    try {
      final service = ref.read(notificationServiceProvider);

      // Handle daily reminder scheduling/canceling
      if (updated.expenseRemindersEnabled) {
        await service.requestPermissions();
        await service.scheduleDailyReminder(
          hour: updated.reminderHour,
          minute: updated.reminderMinute,
        );
      } else if (current.expenseRemindersEnabled &&
          !updated.expenseRemindersEnabled) {
        await service.cancelDailyReminder();
      }

      await ref
          .read(notificationRepositoryProvider)
          .updatePreferences(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update notification settings: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    NotificationPreferences prefs,
  ) async {
    final initial = TimeOfDay(
      hour: prefs.reminderHour,
      minute: prefs.reminderMinute,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null &&
        (picked.hour != prefs.reminderHour ||
            picked.minute != prefs.reminderMinute)) {
      final updated = prefs.copyWith(
        reminderHour: picked.hour,
        reminderMinute: picked.minute,
      );
      await _updatePreferences(prefs, updated);
    }
  }

  Future<void> _editLargeExpenseThreshold(
    BuildContext context,
    NotificationPreferences prefs,
  ) async {
    final currentRupees =
        (prefs.largeExpenseThresholdMinorUnits / 100).toStringAsFixed(0);
    final controller = TextEditingController(text: currentRupees);

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Large expense threshold'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Threshold (₹)',
              prefixText: '₹ ',
              hintText: '5000',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                final rupees = int.tryParse(text);
                if (rupees != null && rupees > 0) {
                  Navigator.of(dialogContext).pop(rupees * 100);
                } else {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null && result != prefs.largeExpenseThresholdMinorUnits) {
      final updated = prefs.copyWith(
        largeExpenseThresholdMinorUnits: result,
      );
      await _updatePreferences(prefs, updated);
    }
  }

  String _formatTimeOfDay(int hour, int minute) {
    final time = TimeOfDay(hour: hour, minute: minute);
    final hourOfPeriod = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minuteStr = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hourOfPeriod:$minuteStr $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final prefs = prefsAsync.value ?? const NotificationPreferences();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification Types Card
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Notification preferences',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      value: prefs.budgetAlertsEnabled,
                      onChanged: _isUpdating
                          ? null
                          : (val) {
                              final updated = prefs.copyWith(
                                budgetAlertsEnabled: val,
                              );
                              _updatePreferences(prefs, updated);
                            },
                      title: const Text('Budget alerts'),
                      subtitle: const Text(
                        'Notify when spending reaches 80% or exceeds budget',
                      ),
                      secondary: const Icon(Icons.pie_chart_outline),
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    SwitchListTile(
                      value: prefs.expenseRemindersEnabled,
                      onChanged: _isUpdating
                          ? null
                          : (val) {
                              final updated = prefs.copyWith(
                                expenseRemindersEnabled: val,
                              );
                              _updatePreferences(prefs, updated);
                            },
                      title: const Text('Expense reminders'),
                      subtitle: const Text(
                        'Daily reminder to record your expenses',
                      ),
                      secondary: const Icon(Icons.alarm_outlined),
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    SwitchListTile(
                      value: prefs.spendingInsightsEnabled,
                      onChanged: _isUpdating
                          ? null
                          : (val) {
                              final updated = prefs.copyWith(
                                spendingInsightsEnabled: val,
                              );
                              _updatePreferences(prefs, updated);
                            },
                      title: const Text('Spending insights'),
                      subtitle: const Text(
                        'Notify about spending trends and comparisons',
                      ),
                      secondary: const Icon(Icons.insights_outlined),
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    SwitchListTile(
                      value: prefs.largeExpenseAlertsEnabled,
                      onChanged: _isUpdating
                          ? null
                          : (val) {
                              final updated = prefs.copyWith(
                                largeExpenseAlertsEnabled: val,
                              );
                              _updatePreferences(prefs, updated);
                            },
                      title: const Text('Large expense alerts'),
                      subtitle: const Text(
                        'Notify when an expense reaches the threshold',
                      ),
                      secondary: const Icon(Icons.warning_amber_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Configuration Card
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Configuration',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Reminder time'),
                      subtitle: Text(
                        _formatTimeOfDay(
                          prefs.reminderHour,
                          prefs.reminderMinute,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _isUpdating
                          ? null
                          : () => _pickReminderTime(context, prefs),
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    ListTile(
                      leading: const Icon(Icons.currency_rupee_outlined),
                      title: const Text('Large expense threshold'),
                      subtitle: Text(
                        formatMinorUnits(
                          prefs.largeExpenseThresholdMinorUnits,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _isUpdating
                          ? null
                          : () => _editLargeExpenseThreshold(context, prefs),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Preferences are automatically saved for your account.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
