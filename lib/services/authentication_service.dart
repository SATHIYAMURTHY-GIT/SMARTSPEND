import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../repositories/user_profile_repository.dart';

class AuthenticationException implements Exception {
  const AuthenticationException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => code != null ? '[$code] $message' : message;
}

class AuthenticationService {
  AuthenticationService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    UserProfileRepository? userProfileRepository,
  }) : _authInstance = auth,
       _googleSignInInstance = googleSignIn,
       _userProfileRepository =
           userProfileRepository ?? UserProfileRepository();

  final FirebaseAuth? _authInstance;
  final GoogleSignIn? _googleSignInInstance;
  final UserProfileRepository _userProfileRepository;
  Future<void>? _googleInitialization;

  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn =>
      _googleSignInInstance ?? GoogleSignIn.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signInWithGoogle() async {
    try {
      _googleInitialization ??= _googleSignIn.initialize(
        serverClientId:
        '248524051938-b1sbmgisg8g9qfhl053t7tj19vn6div3.apps.googleusercontent.com',
      );
      await _googleInitialization;
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null) {
        throw const AuthenticationException(
          'Google sign-in could not be completed.',
          code: 'no-id-token',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      await _userProfileRepository.upsertForUser(result.user!);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthenticationException(
          'Sign-in was cancelled.',
          code: 'canceled',
        );
      }
      debugPrint('Google sign-in failed: ${error.code}');
      throw AuthenticationException(
        'We could not sign you in with Google. Please try again.',
        code: error.code.name,
      );
    } on FirebaseException catch (error) {
      debugPrint('Firebase authentication failed: ${error.code}');
      throw AuthenticationException(
        'We could not sign you in right now. Please try again.',
        code: error.code,
      );
    } on AuthenticationException {
      rethrow;
    } catch (error) {
      debugPrint('Authentication failed: $error');
      throw AuthenticationException(
        'We could not sign you in right now. Please try again.',
        code: error.runtimeType.toString(),
      );
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> deleteAccount({FirebaseFirestore? firestore}) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[AccountDeletion] Failed: No authenticated user found.');
      throw const AuthenticationException(
        'No authenticated user found.',
        code: 'no-user',
      );
    }

    final userId = user.uid;
    final db = firestore ?? FirebaseFirestore.instance;
    debugPrint('[AccountDeletion] Step 1: Initiating account deletion for uid: $userId, email: ${user.email}');

    try {
      // 1. Delete all user expenses
      debugPrint('[AccountDeletion] Step 2: Fetching expenses collection for uid: $userId');
      final expensesSnapshot = await db
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .get();
      debugPrint('[AccountDeletion] Step 2a: Found ${expensesSnapshot.docs.length} expenses to delete');
      for (final doc in expensesSnapshot.docs) {
        debugPrint('[AccountDeletion] Step 2b: Deleting expense doc ${doc.id}');
        await doc.reference.delete();
      }
      debugPrint('[AccountDeletion] Step 2c: All expenses deleted successfully');

      // 2. Delete all user settings documents (profile, budget, notifications, etc.)
      debugPrint('[AccountDeletion] Step 3: Fetching settings collection for uid: $userId');
      final settingsSnapshot = await db
          .collection('users')
          .doc(userId)
          .collection('settings')
          .get();
      debugPrint('[AccountDeletion] Step 3a: Found ${settingsSnapshot.docs.length} settings docs to delete');
      for (final doc in settingsSnapshot.docs) {
        debugPrint('[AccountDeletion] Step 3b: Deleting settings doc ${doc.id}');
        await doc.reference.delete();
      }
      debugPrint('[AccountDeletion] Step 3c: All settings docs deleted successfully');

      // 3. Delete user root document
      debugPrint('[AccountDeletion] Step 4: Deleting root document users/$userId');
      await db.collection('users').doc(userId).delete();
      debugPrint('[AccountDeletion] Step 4b: Root user document deleted successfully');

      // 4. Delete the Firebase Authentication account
      debugPrint('[AccountDeletion] Step 5: Attempting user.delete() on FirebaseAuth');
      try {
        await user.delete();
        debugPrint('[AccountDeletion] Step 5b: FirebaseAuth user deleted successfully');
      } on FirebaseAuthException catch (e, stack) {
        debugPrint('[AccountDeletion] Step 5 caught FirebaseAuthException: code=${e.code}, message=${e.message}');
        if (e.code == 'requires-recent-login') {
          debugPrint('[AccountDeletion] Step 6: Triggering Google re-authentication');
          _googleInitialization ??= _googleSignIn.initialize(
            serverClientId:
                '248524051938-b1sbmgisg8g9qfhl053t7tj19vn6div3.apps.googleusercontent.com',
          );
          await _googleInitialization;
          final account = await _googleSignIn.authenticate();
          final idToken = account.authentication.idToken;
          if (idToken == null) {
            debugPrint('[AccountDeletion] Step 6 error: idToken is null after re-auth');
            throw const AuthenticationException(
              'Reauthentication was cancelled or failed.',
              code: 'reauth-no-token',
            );
          }
          debugPrint('[AccountDeletion] Step 6b: Got idToken, reauthenticating with credential');
          final credential = GoogleAuthProvider.credential(idToken: idToken);
          await user.reauthenticateWithCredential(credential);
          debugPrint('[AccountDeletion] Step 6c: Re-authenticated successfully, retrying user.delete()');
          await user.delete();
          debugPrint('[AccountDeletion] Step 6d: User deleted successfully after re-authentication');
        } else {
          debugPrint('[AccountDeletion] Step 5 unhandled FirebaseAuthException: $e, stack: $stack');
          rethrow;
        }
      }

      // 5. Sign out from Google sign-in
      debugPrint('[AccountDeletion] Step 7: Signing out from Google Sign-In');
      await _googleSignIn.signOut();
      debugPrint('[AccountDeletion] Step 8: Account deletion completed successfully.');
    } on FirebaseAuthException catch (error, stack) {
      debugPrint('[AccountDeletion] Error: FirebaseAuthException [${error.code}]: ${error.message}');
      debugPrint('[AccountDeletion] Stack: $stack');
      throw AuthenticationException(
        error.message ?? 'Failed to delete authentication account.',
        code: error.code,
      );
    } on FirebaseException catch (error, stack) {
      debugPrint('[AccountDeletion] Error: FirebaseException (${error.plugin}) [${error.code}]: ${error.message}');
      debugPrint('[AccountDeletion] Stack: $stack');
      throw AuthenticationException(
        error.message ?? 'Failed to delete user data.',
        code: '${error.plugin}/${error.code}',
      );
    } on GoogleSignInException catch (error, stack) {
      debugPrint('[AccountDeletion] Error: GoogleSignInException [${error.code}]: ${error.description}');
      debugPrint('[AccountDeletion] Stack: $stack');
      throw AuthenticationException(
        error.description ?? 'Google re-authentication failed.',
        code: error.code.name,
      );
    } on AuthenticationException {
      rethrow;
    } catch (error, stack) {
      debugPrint('[AccountDeletion] Unexpected error (${error.runtimeType}): $error');
      debugPrint('[AccountDeletion] Stack: $stack');
      throw AuthenticationException(
        'Unexpected error: $error',
        code: error.runtimeType.toString(),
      );
    }
  }
}