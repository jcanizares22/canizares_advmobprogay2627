import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/dummy_json_auth_service.dart';
import '../services/user_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    UserService? userService,
    DummyJsonAuthService? dummyJsonAuthService,
  }) : _userService = userService ?? UserService(),
       _dummyJsonAuthService = dummyJsonAuthService ?? DummyJsonAuthService() {
    _firebaseUser = _userService.currentUser;
    _authSubscription = _userService.authStateChanges.listen(
      (user) => unawaited(_handleAuthChange(user)),
      onError: (Object error) {
        _errorMessage = _friendlyError(error);
        _isInitializing = false;
        notifyListeners();
      },
    );
    if (_firebaseUser != null) {
      unawaited(_loadProfile());
    }
  }

  final UserService _userService;
  final DummyJsonAuthService _dummyJsonAuthService;
  late final StreamSubscription<firebase_auth.User?> _authSubscription;
  firebase_auth.User? _firebaseUser;
  UserModel? _user;
  DummyJsonAuthResult? _dummyJsonSession;
  LoginType _loginType = LoginType.firebase;
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _isCreatingAccount = false;
  String? _errorMessage;
  Future<void>? _profileLoad;

  UserModel? get user => _user;
  LoginType get loginType => _loginType;
  firebase_auth.User? get firebaseUser => _firebaseUser;
  bool get isAuthenticated => _loginType == LoginType.dummyJson
      ? _dummyJsonSession != null
      : _firebaseUser != null;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> signIn(String email, String password) {
    return _run(() async {
      await _userService.signIn(email, password);
      _loginType = LoginType.firebase;
      _dummyJsonSession = null;
      _firebaseUser = _userService.currentUser;
    });
  }

  Future<bool> signInWithDummyJson(String username, String password) {
    return _run(() async {
      if (_firebaseUser != null) await _userService.signOut();
      final session = await _dummyJsonAuthService.signIn(username, password);
      _firebaseUser = null;
      _user = session.user;
      _dummyJsonSession = session;
      _loginType = LoginType.dummyJson;
      _isInitializing = false;
    });
  }

  Future<bool> createAccount({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required int age,
    required String contactNumber,
    required String username,
  }) {
    return _run(() async {
      _isCreatingAccount = true;
      try {
        final credential = await _userService.createAccount(email, password);
        final authUser = credential?.user;
        if (authUser == null) {
          throw StateError('Firebase did not return a user ID.');
        }

        final profile = UserModel(
          uid: authUser.uid,
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          age: age,
          contactNumber: contactNumber.trim(),
          username: username.trim(),
          email: email.trim(),
        );
        try {
          await _userService.saveUserData(profile);
        } catch (error) {
          try {
            await authUser.delete();
          } on firebase_auth.FirebaseAuthException catch (cleanupError) {
            throw StateError(
              'The profile could not be saved to Firestore ($error), and '
              'the new Firebase account could not be removed '
              '(${cleanupError.message ?? cleanupError.code}).',
            );
          }
          rethrow;
        }

        await _userService.signOut();
        _loginType = LoginType.firebase;
        _dummyJsonSession = null;
        _firebaseUser = null;
        _isInitializing = false;
        _user = null;
      } finally {
        _isCreatingAccount = false;
      }
    });
  }

  Future<bool> signOut() {
    return _run(() async {
      if (_loginType == LoginType.dummyJson) {
        _dummyJsonSession = null;
        _loginType = LoginType.firebase;
      } else {
        await _userService.signOut();
      }
      _user = null;
      _firebaseUser = null;
    });
  }

  Future<bool> resetPassword(String email) {
    return _run(() => _userService.resetPassword(email));
  }

  Future<bool> updateUsername(String username) {
    return _run(() async {
      final profile = _user;
      if (profile == null) {
        throw StateError('Your account profile has not finished loading.');
      }
      await _userService.updateUsername(profile, username);
      _user = profile.copyWith(username: username.trim());
    });
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return resetPasswordFromCurrentPassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<bool> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _run(
      () => _userService.resetPasswordFromCurrentPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
  }

  Future<bool> deleteAccount({String? currentPassword}) {
    return _run(() async {
      if (currentPassword != null && currentPassword.isNotEmpty) {
        await _userService.reauthenticate(currentPassword);
      }
      await _userService.deleteAccount();
      _user = null;
      _firebaseUser = null;
      _dummyJsonSession = null;
      _loginType = LoginType.firebase;
    });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _handleAuthChange(firebase_auth.User? user) async {
    if (_isCreatingAccount) return;
    if (user != null) {
      final hasCurrentProfile = _user?.uid == user.uid;
      _loginType = LoginType.firebase;
      _dummyJsonSession = null;
      _firebaseUser = user;
      if (!hasCurrentProfile) await _loadProfile();
    } else if (_loginType != LoginType.dummyJson) {
      _firebaseUser = null;
      _user = null;
    }
    _isInitializing = false;
    notifyListeners();
  }

  Future<void> _loadProfile() {
    final currentLoad = _profileLoad;
    if (currentLoad != null) return currentLoad;

    final load = _loadProfileData();
    _profileLoad = load;
    return load.whenComplete(() {
      if (identical(_profileLoad, load)) _profileLoad = null;
    });
  }

  Future<void> _loadProfileData() async {
    try {
      _user = UserModel.fromMap(await _userService.getUserData());
    } catch (error) {
      _errorMessage = _friendlyError(error);
      final authUser = _userService.currentUser;
      if (authUser != null) {
        _user = UserModel(
          uid: authUser.uid,
          firstName: '',
          lastName: '',
          age: 0,
          contactNumber: '',
          username: authUser.displayName ?? '',
          email: authUser.email ?? '',
        );
      }
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on firebase_auth.FirebaseAuthException catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } on FirebaseException catch (error) {
      _errorMessage = error.message ?? 'A Firebase request failed.';
      return false;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    if (error is firebase_auth.FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Enter a valid email address.',
        'email-already-in-use' => 'An account already exists for this email.',
        'weak-password' => 'Choose a stronger password.',
        'user-not-found' ||
        'invalid-credential' ||
        'wrong-password' => 'The email or password is incorrect.',
        'user-disabled' => 'This account has been disabled.',
        'operation-not-allowed' =>
          'Email and password sign-in is not enabled in Firebase.',
        'requires-recent-login' =>
          'Sign in again before performing this account change.',
        'network-request-failed' => 'Check your internet connection and retry.',
        _ => error.message ?? 'Authentication failed. Please try again.',
      };
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}
