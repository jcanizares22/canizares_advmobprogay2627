import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/user_model.dart';

class UserService {
  UserService({firebase_auth.FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  firebase_auth.User? get currentUser => _auth.currentUser;

  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  Future<firebase_auth.UserCredential?> signIn(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on firebase_auth.FirebaseAuthException {
      rethrow;
    }
  }

  Future<firebase_auth.UserCredential?> createAccount(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on firebase_auth.FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> saveUserData(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> updateUsername(String username) async {
    final user = _requireCurrentUser();
    final updatedUsername = username.trim();
    await user.updateDisplayName(updatedUsername);
    await _firestore.collection('users').doc(user.uid).set({
      'username': updatedUsername,
    }, SetOptions(merge: true));
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on firebase_auth.FirebaseAuthException {
      rethrow;
    }
  }

  Future<void> reauthenticate(String password) async {
    final user = _requireCurrentUser();
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('The current account has no email address.');
    }
    final credential = firebase_auth.EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await resetPasswordFromCurrentPassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await reauthenticate(currentPassword);
    await _requireCurrentUser().updatePassword(newPassword);
  }

  Future<void> deleteAccount() async {
    final user = _requireCurrentUser();
    await _firestore.collection('users').doc(user.uid).delete();
    await user.delete();
  }

  Future<Map<String, dynamic>> getUserData() async {
    final user = _requireCurrentUser();
    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    return {
      ...?snapshot.data(),
      'uid': user.uid,
      'email': user.email ?? '',
      'loginType': LoginType.firebase.name,
      'username':
          snapshot.data()?['username'] as String? ?? user.displayName ?? '',
    };
  }

  firebase_auth.User _requireCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user is signed in.');
    return user;
  }
}
