import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/widgets/user_avatar_widget.dart';
import 'package:smartspend/models/expense.dart';
import 'package:smartspend/models/user_profile.dart';
import 'package:smartspend/providers/authentication_provider.dart';
import 'package:smartspend/providers/expense_provider.dart';
import 'package:smartspend/providers/user_profile_provider.dart';
import 'package:smartspend/repositories/user_profile_repository.dart';
import 'package:smartspend/screens/home/home_screen.dart';
import 'package:smartspend/screens/profile/profile_screen.dart';

class FakeUserProfileRepository extends UserProfileRepository {
  FakeUserProfileRepository({UserProfile? initialProfile})
      : _profile = initialProfile;

  UserProfile? _profile;
  final List<UserProfile?> _history = [];

  UserProfile? get currentProfile => _profile;

  @override
  Future<UserProfile?> getProfile() async => _profile;

  @override
  Stream<UserProfile?> watchProfile() async* {
    yield _profile;
  }

  @override
  Future<void> updateProfile({String? displayName, String? avatar}) async {
    if (displayName != null) {
      final trimmed = displayName.trim();
      if (trimmed.isEmpty) {
        throw ArgumentError('Username cannot be empty.');
      }
      _profile = (_profile ?? const UserProfile(userId: 'test_user'))
          .copyWith(displayName: trimmed);
    }

    if (avatar != null) {
      _profile = (_profile ?? const UserProfile(userId: 'test_user'))
          .copyWith(avatar: avatar.trim().toLowerCase());
    }

    _history.add(_profile);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppAvatar Enum & 5 Avatars Requirements', () {
    test('contains EXACTLY FIVE avatar options', () {
      expect(AppAvatar.values.length, 5);
    });

    test('includes Giraffe avatar and all other 4 animal avatars with expected assets', () {
      final ids = AppAvatar.values.map((a) => a.id).toList();
      expect(ids, containsAll(['rabbit', 'elephant', 'deer', 'cheetah', 'giraffe']));

      expect(AppAvatar.rabbit.assetPath, 'assets/images/RABBIT.png');
      expect(AppAvatar.elephant.assetPath, 'assets/images/ELEPHANT.png');
      expect(AppAvatar.deer.assetPath, 'assets/images/DEER.png');
      expect(AppAvatar.cheetah.assetPath, 'assets/images/CHEETAH.png');
      expect(AppAvatar.giraffe.assetPath, 'assets/images/GIRAFFE.png');
    });

    test('AppAvatar.fromId resolves correctly with safe fallback', () {
      expect(AppAvatar.fromId('giraffe'), AppAvatar.giraffe);
      expect(AppAvatar.fromId('GIRAFFE'), AppAvatar.giraffe);
      expect(AppAvatar.fromId('rabbit'), AppAvatar.rabbit);
      expect(AppAvatar.fromId('elephant'), AppAvatar.elephant);
      expect(AppAvatar.fromId('deer'), AppAvatar.deer);
      expect(AppAvatar.fromId('cheetah'), AppAvatar.cheetah);
      expect(AppAvatar.fromId(null), AppAvatar.rabbit);
      expect(AppAvatar.fromId('unknown'), AppAvatar.rabbit);
    });
  });

  group('UserProfile Model', () {
    test('safeDisplayName falls back to SmartSpend when empty or null', () {
      const emptyProfile = UserProfile(userId: 'u1', displayName: '');
      expect(emptyProfile.safeDisplayName, 'SmartSpend');

      const spaceProfile = UserProfile(userId: 'u1', displayName: '   ');
      expect(spaceProfile.safeDisplayName, 'SmartSpend');

      const nullProfile = UserProfile(userId: 'u1', displayName: null);
      expect(nullProfile.safeDisplayName, 'SmartSpend');

      const validProfile = UserProfile(userId: 'u1', displayName: 'Sathiya');
      expect(validProfile.safeDisplayName, 'Sathiya');
    });

    test('fromFirestore and toFirestore preserve fields', () {
      final model = UserProfile.fromFirestore({
        'userId': 'u123',
        'displayName': '  Sathiya  ',
        'avatar': 'giraffe',
      }, userId: 'u123');

      expect(model.userId, 'u123');
      expect(model.displayName, '  Sathiya  ');
      expect(model.safeDisplayName, 'Sathiya');
      expect(model.avatar, 'giraffe');
      expect(model.appAvatar, AppAvatar.giraffe);

      final payload = model.toFirestore();
      expect(payload['userId'], 'u123');
      expect(payload['displayName'], 'Sathiya');
      expect(payload['avatar'], 'giraffe');
    });
  });

  group('ProfileScreen Widgets & Interactions', () {
    testWidgets('displays all 5 avatars and allows selecting Giraffe, Rabbit, etc.', (tester) async {
      final fakeRepo = FakeUserProfileRepository(
        initialProfile: const UserProfile(
          userId: 'test_user',
          displayName: 'Sathiya',
          avatar: 'rabbit',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileRepositoryProvider.overrideWithValue(fakeRepo),
            userProfileProvider.overrideWith((ref) => Stream.value(fakeRepo.currentProfile)),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 5 avatar labels appear
      expect(find.text('Rabbit'), findsOneWidget);
      expect(find.text('Elephant'), findsOneWidget);
      expect(find.text('Deer'), findsOneWidget);
      expect(find.text('Cheetah'), findsOneWidget);
      expect(find.text('Giraffe'), findsOneWidget);

      // Tap Giraffe
      await tester.tap(find.text('Giraffe'));
      await tester.pumpAndSettle();

      expect(fakeRepo.currentProfile?.avatar, 'giraffe');

      // Tap Elephant
      await tester.tap(find.text('Elephant'));
      await tester.pumpAndSettle();

      expect(fakeRepo.currentProfile?.avatar, 'elephant');
    });

    testWidgets('validates username: trims and rejects empty name', (tester) async {
      final fakeRepo = FakeUserProfileRepository(
        initialProfile: const UserProfile(
          userId: 'test_user',
          displayName: 'Initial User',
          avatar: 'rabbit',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileRepositoryProvider.overrideWithValue(fakeRepo),
            userProfileProvider.overrideWith((ref) => Stream.value(fakeRepo.currentProfile)),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear input and save -> error
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid name'), findsOneWidget);

      // Enter valid name with trailing spaces
      await tester.enterText(find.byType(TextFormField), '  Sathiya  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeRepo.currentProfile?.displayName, 'Sathiya');
    });

    testWidgets('username save removes focus, dismisses keyboard, and keeps saved username visible', (tester) async {
      final fakeRepo = FakeUserProfileRepository(
        initialProfile: const UserProfile(
          userId: 'test_user',
          displayName: 'Initial User',
          avatar: 'rabbit',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileRepositoryProvider.overrideWithValue(fakeRepo),
            userProfileProvider.overrideWith((ref) => Stream.value(fakeRepo.currentProfile)),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextFormField);
      // Focus the text field and enter text
      await tester.tap(textFieldFinder);
      await tester.pumpAndSettle();

      final textFieldBefore = tester.widget<TextField>(
        find.descendant(of: textFieldFinder, matching: find.byType(TextField)),
      );
      expect(textFieldBefore.focusNode?.hasFocus, isTrue);

      await tester.enterText(textFieldFinder, 'Sathiya New');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify repository updated
      expect(fakeRepo.currentProfile?.displayName, 'Sathiya New');

      // Verify focus is removed from the text field
      final textFieldAfter = tester.widget<TextField>(
        find.descendant(of: textFieldFinder, matching: find.byType(TextField)),
      );
      expect(textFieldAfter.focusNode?.hasFocus, isFalse);
      expect(FocusManager.instance.primaryFocus != textFieldBefore.focusNode, isTrue);

      // Verify saved name remains visible in the text field
      final textFieldWidget = tester.widget<TextFormField>(textFieldFinder);
      expect(textFieldWidget.controller?.text, 'Sathiya New');
    });

    testWidgets('Appearance section has inline theme options and NO popup sheet', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Verify no modal bottom sheet is shown on tapping Appearance ListTile
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();

      expect(find.text('Choose theme'), findsNothing);
    });

    testWidgets('handles long usernames without layout overflow', (tester) async {
      final fakeRepo = FakeUserProfileRepository(
        initialProfile: const UserProfile(
          userId: 'test_user',
          displayName: 'SuperExtremelyLongNameThatCouldPotentiallyOverflowTheHeaderCardLayoutIfNotHandled',
          avatar: 'giraffe',
        ),
      );

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileRepositoryProvider.overrideWithValue(fakeRepo),
            userProfileProvider.overrideWith((ref) => Stream.value(fakeRepo.currentProfile)),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Dashboard Integration (HomeScreen)', () {
    testWidgets('renders saved username, right-side avatar, and View expenses in dashboard header', (tester) async {
      final profile = const UserProfile(
        userId: 'u1',
        displayName: 'Sathiyamurthi',
        avatar: 'giraffe',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(profile)),
            expensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Full name displayed without truncation
      expect(find.text('Sathiyamurthi'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('View expenses'), findsWidgets);

      // Removed clutter
      expect(find.text('Your money snapshot'), findsNothing);

      // Avatars: one in AppBar, one in Welcome card
      expect(find.byType(UserAvatarWidget), findsNWidgets(2));
    });

    testWidgets('falls back to SmartSpend on dashboard when profile has no name', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(null)),
            expensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SmartSpend'), findsWidgets);
    });

    testWidgets('handles long multi-word usernames on dashboard header without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profile = const UserProfile(
        userId: 'u1',
        displayName: 'Sathiyamurthi Ramasamy',
        avatar: 'giraffe',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(profile)),
            expensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sathiyamurthi Ramasamy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
