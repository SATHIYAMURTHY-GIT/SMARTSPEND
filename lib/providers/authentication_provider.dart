import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/user_profile_repository.dart';
import '../services/authentication_service.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository();
});

final authenticationServiceProvider = Provider<AuthenticationService>((ref) {
  return AuthenticationService(
    userProfileRepository: ref.watch(userProfileRepositoryProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authenticationServiceProvider).authStateChanges;
});

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(authenticationServiceProvider));
});

class AuthController {
  const AuthController(this._service);

  final AuthenticationService _service;

  Future<void> signInWithGoogle() => _service.signInWithGoogle();

  Future<void> signOut() => _service.signOut();

  Future<void> deleteAccount() => _service.deleteAccount();
}