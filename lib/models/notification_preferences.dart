class NotificationPreferences {
  const NotificationPreferences({
    this.budgetAlertsEnabled = true,
    this.expenseRemindersEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.spendingInsightsEnabled = true,
    this.largeExpenseAlertsEnabled = false,
    this.largeExpenseThresholdMinorUnits = 500000, // ₹5,000 in minor units
  });

  final bool budgetAlertsEnabled;
  final bool expenseRemindersEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool spendingInsightsEnabled;
  final bool largeExpenseAlertsEnabled;
  final int largeExpenseThresholdMinorUnits;

  NotificationPreferences copyWith({
    bool? budgetAlertsEnabled,
    bool? expenseRemindersEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? spendingInsightsEnabled,
    bool? largeExpenseAlertsEnabled,
    int? largeExpenseThresholdMinorUnits,
  }) {
    return NotificationPreferences(
      budgetAlertsEnabled: budgetAlertsEnabled ?? this.budgetAlertsEnabled,
      expenseRemindersEnabled:
          expenseRemindersEnabled ?? this.expenseRemindersEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      spendingInsightsEnabled:
          spendingInsightsEnabled ?? this.spendingInsightsEnabled,
      largeExpenseAlertsEnabled:
          largeExpenseAlertsEnabled ?? this.largeExpenseAlertsEnabled,
      largeExpenseThresholdMinorUnits:
          largeExpenseThresholdMinorUnits ?? this.largeExpenseThresholdMinorUnits,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'budgetAlertsEnabled': budgetAlertsEnabled,
      'expenseRemindersEnabled': expenseRemindersEnabled,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'spendingInsightsEnabled': spendingInsightsEnabled,
      'largeExpenseAlertsEnabled': largeExpenseAlertsEnabled,
      'largeExpenseThresholdMinorUnits': largeExpenseThresholdMinorUnits,
    };
  }

  factory NotificationPreferences.fromFirestore(Map<String, dynamic> data) {
    return NotificationPreferences(
      budgetAlertsEnabled: data['budgetAlertsEnabled'] as bool? ?? true,
      expenseRemindersEnabled:
          data['expenseRemindersEnabled'] as bool? ?? false,
      reminderHour: (data['reminderHour'] as num?)?.toInt() ?? 20,
      reminderMinute: (data['reminderMinute'] as num?)?.toInt() ?? 0,
      spendingInsightsEnabled:
          data['spendingInsightsEnabled'] as bool? ?? true,
      largeExpenseAlertsEnabled:
          data['largeExpenseAlertsEnabled'] as bool? ?? false,
      largeExpenseThresholdMinorUnits:
          (data['largeExpenseThresholdMinorUnits'] as num?)?.toInt() ?? 500000,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferences &&
          runtimeType == other.runtimeType &&
          budgetAlertsEnabled == other.budgetAlertsEnabled &&
          expenseRemindersEnabled == other.expenseRemindersEnabled &&
          reminderHour == other.reminderHour &&
          reminderMinute == other.reminderMinute &&
          spendingInsightsEnabled == other.spendingInsightsEnabled &&
          largeExpenseAlertsEnabled == other.largeExpenseAlertsEnabled &&
          largeExpenseThresholdMinorUnits ==
              other.largeExpenseThresholdMinorUnits;

  @override
  int get hashCode => Object.hash(
        budgetAlertsEnabled,
        expenseRemindersEnabled,
        reminderHour,
        reminderMinute,
        spendingInsightsEnabled,
        largeExpenseAlertsEnabled,
        largeExpenseThresholdMinorUnits,
      );
}
