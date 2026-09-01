import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../providers/authentication_provider.dart';

final userProfileProvider = StreamProvider.autoDispose<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) => user == null
        ? Stream.value(null)
        : ref.watch(userProfileRepositoryProvider).watchProfile(),
    loading: () => Stream.value(null),
    error: (error, stackTrace) => Stream.value(null),
  );
});

