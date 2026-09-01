import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_preferences.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_service.dart';
import 'authentication_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.initialize();
  return service;
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final notificationPreferencesProvider =
    StreamProvider.autoDispose<NotificationPreferences>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) => user == null
        ? Stream.value(const NotificationPreferences())
        : ref.watch(notificationRepositoryProvider).watchPreferences(),
    loading: () => Stream.value(const NotificationPreferences()),
    error: (error, stackTrace) => Stream.value(const NotificationPreferences()),
  );
});
