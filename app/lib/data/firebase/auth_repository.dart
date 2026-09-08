import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../models/user_profile.dart';

/// Thrown for auth failures we want to surface as a readable message.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Real Firebase Authentication.
///
/// This replaces the web build's local placeholder entirely: there are no
/// client-held account records, and Pro is never derived from a client flag —
/// it is read from the user's Firestore profile, which only the receipt
/// verification function may write.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _google = googleSignIn ?? GoogleSignIn(scopes: <String>['email']);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _google;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  /// Live profile document for the signed-in user, including the server-owned
  /// `isPro` entitlement.
  Stream<UserProfile?> profileStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> d) =>
          d.exists ? UserProfile.fromFirestore(uid, d.data() ?? <String, dynamic>{}) : null);

  // ------------------------------------------------------------ providers ---

  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _google.signIn();
      if (account == null) throw const AuthFailure('Sign-in cancelled.');
      final GoogleSignInAuthentication auth = await account.authentication;
      final OAuthCredential cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final UserCredential result = await _auth.signInWithCredential(cred);
      await _ensureProfile(result, provider: 'google.com');
      return result;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  /// Sign in with Apple. Required by App Store Review Guideline 4.8 whenever
  /// another third-party sign-in is offered, so it is not optional on iOS.
  Future<UserCredential> signInWithApple() async {
    try {
      final String rawNonce = _nonce();
      final AuthorizationCredentialAppleID apple =
          await SignInWithApple.getAppleIDCredential(
        scopes: <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
      final OAuthCredential cred = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        rawNonce: rawNonce,
      );
      final UserCredential result = await _auth.signInWithCredential(cred);

      // Apple returns the name only on the very first authorisation.
      final String? given = apple.givenName;
      final String? family = apple.familyName;
      final String assembled = <String?>[given, family]
          .where((String? s) => s != null && s.isNotEmpty)
          .join(' ');
      if (assembled.isNotEmpty && (result.user?.displayName?.isEmpty ?? true)) {
        await result.user?.updateDisplayName(assembled);
      }
      await _ensureProfile(result, provider: 'apple.com', fallbackName: assembled);
      return result;
    } on SignInWithAppleAuthorizationException catch (e) {
      throw AuthFailure(
        e.code == AuthorizationErrorCode.canceled
            ? 'Sign-in cancelled.'
            : 'Apple sign-in failed. Please try again.',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName != null && displayName.trim().isNotEmpty) {
        await result.user?.updateDisplayName(displayName.trim());
      }
      await _ensureProfile(result, provider: 'password', fallbackName: displayName);
      return result;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _ensureProfile(result, provider: 'password');
      return result;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  Future<void> signOut() async {
    // Google sign-out can throw when the user never used that provider; the
    // Firebase sign-out below is the one that must happen.
    try {
      await _google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Permanent account deletion, required by App Store Guideline 5.1.1(v) for
  /// any app that lets a user create an account. Deleting the auth user
  /// triggers the `onUserDeleted` function, which removes their Firestore data.
  Future<void> deleteAccount() async {
    final User? u = _auth.currentUser;
    if (u == null) return;
    try {
      await u.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthFailure(
          'For your security, please sign in again before deleting your account.',
        );
      }
      throw AuthFailure(_message(e));
    }
  }

  // -------------------------------------------------------------- helpers ---

  /// Creates the profile document on first sign-in. `isPro` is deliberately not
  /// written here — the client may never grant itself the entitlement.
  Future<void> _ensureProfile(
    UserCredential result, {
    required String provider,
    String? fallbackName,
  }) async {
    final User? u = result.user;
    if (u == null) return;
    final DocumentReference<Map<String, dynamic>> ref = _db.collection('users').doc(u.uid);
    final Map<String, dynamic> data = <String, dynamic>{
      'email': u.email,
      'displayName': u.displayName ?? fallbackName,
      'provider': provider,
      'lastSeenAt': FieldValue.serverTimestamp(),
      if (result.additionalUserInfo?.isNewUser ?? false)
        'createdAt': FieldValue.serverTimestamp(),
    };
    await ref.set(data, SetOptions(merge: true));
  }

  static String _nonce([int length = 32]) {
    const String chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final Random rnd = Random.secure();
    return List<String>.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  static bool get appleSignInAvailable => Platform.isIOS || Platform.isMacOS;

  static String _message(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address does not look right.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'Please choose a password of at least 6 characters.',
        'network-request-failed' => 'No connection. Please check your network.',
        'too-many-requests' => 'Too many attempts. Please try again shortly.',
        'account-exists-with-different-credential' =>
          'That email is already registered with a different sign-in method.',
        _ => e.message ?? 'Sign-in failed. Please try again.',
      };
}
