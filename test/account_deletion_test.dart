import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/models/user_profile.dart';
import 'package:smartspend/providers/authentication_provider.dart';
import 'package:smartspend/providers/notification_provider.dart';
import 'package:smartspend/providers/user_profile_provider.dart';
import 'package:smartspend/repositories/user_profile_repository.dart';
import 'package:smartspend/screens/profile/profile_screen.dart';
import 'package:smartspend/services/authentication_service.dart';
import 'package:smartspend/services/notification_service.dart';

class FakeAuthenticationService extends AuthenticationService {
  bool deleteAccountCalled = false;
  bool signOutCalled = false;

  @override
  Future<void> deleteAccount({dynamic firestore}) async {
    deleteAccountCalled = true;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

class FakeNotificationService extends NotificationService {
  bool cancelAllCalled = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelAll() async {
    cancelAllCalled = true;
  }
}

class FakeUserProfileRepository extends UserProfileRepository {
  FakeUserProfileRepository({this.initialProfile});

  final UserProfile? initialProfile;

  @override
  Future<UserProfile?> getProfile() async => initialProfile;

  @override
  Stream<UserProfile?> watchProfile() async* {
    yield initialProfile;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Account Deletion UI & Workflows', () {
    testWidgets('Account section renders with Delete account tile in ProfileScreen', (tester) async {
      final fakeAuth = FakeAuthenticationService();
      final fakeRepo = FakeUserProfileRepository(
        initialProfile: const UserProfile(
          userId: 'u1',
          displayName: 'Test User',
          avatar: 'rabbit',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authenticationServiceProvider.overrideWithValue(fakeAuth),
            userProfileRepositoryProvider.overrideWithValue(fakeRepo),
            userProfileProvider.overrideWith((ref) => Stream.value(fakeRepo.initialProfile)),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Account section and Delete account tile
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
      expect(
        find.text('Permanently delete your account and all financial data'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping Delete account shows confirmation dialog and Cancel aborts', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeAuth = FakeAuthenticationService();
      final fakeRepo = FakeUserProfileRepository(
        initialProfile: const UserProfile(
          userId: 'u1',
          displayName: 'Test User',
          avatar: 'rabbit',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authenticationServiceProvider.overrideWithValue(fakeAuth),
            userProfileRepositoryProvider.overrideWithValue(fakeRepo),
            userProfileProvider.overrideWith((ref) => Stream.value(fakeRepo.initialProfile)),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Delete account
      await tester.ensureVisible(find.text('Delete account'));
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      // Verify Dialog appears
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog is dismissed and delete was NOT called
      expect(find.text('Delete your account?'), findsNothing);
      expect(fakeAuth.deleteAccountCalled, isFalse);
    });

    testWidgets('Confirming Delete Account invokes deleteAccount and cancels notifications', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeAuth = FakeAuthenticationService();
      final fakeNotifs = FakeNotificationService();
      final fakeRepo = FakeUserProfileRepository(
        initialProfile: const UserProfile(
          userId: 'u1',
          displayName: 'Test User',
          avatar: 'rabbit',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authenticationServiceProvider.overrideWithValue(fakeAuth),
            notificationServiceProvider.overrideWithValue(fakeNotifs),
            userProfileRepositoryProvider.overrideWithValue(fakeRepo),
            userProfileProvider.overrideWith((ref) => Stream.value(fakeRepo.initialProfile)),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Delete account
      await tester.ensureVisible(find.text('Delete account'));
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      // Tap Delete Account inside Dialog
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      expect(fakeAuth.deleteAccountCalled, isTrue);
      expect(fakeNotifs.cancelAllCalled, isTrue);
    });
  });
}
