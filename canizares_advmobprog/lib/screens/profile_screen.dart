import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/user.dart';
import 'cart_screen.dart';
import '../screen/signin_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _userDataKey = 'savedUser';
  late final Future<User> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUser();
  }

  Future<User> _loadUser() async {
    final preferences = await SharedPreferences.getInstance();
    final savedUser = preferences.getString(_userDataKey);
    if (savedUser == null || savedUser.isEmpty) {
      throw Exception('No saved user data found');
    }

    final decoded = jsonDecode(savedUser);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid saved user data');
    }
    return User.fromJson(decoded);
  }

  Future<void> _signOut() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('isLoggedIn');
    await preferences.remove(_userDataKey);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<User>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load profile: ${snapshot.error}'));
          }

          final user = snapshot.data!;
          final colorScheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: user.image.isNotEmpty
                    ? NetworkImage(user.image)
                    : null,
                child: user.image.isEmpty
                    ? Icon(
                        Icons.person,
                        size: 50,
                        color: colorScheme.onPrimaryContainer,
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                user.fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@${user.username}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email'),
                      subtitle: Text(user.email),
                    ),
                    ListTile(
                      leading: const Icon(Icons.wc_outlined),
                      title: const Text('Gender'),
                      subtitle: Text(
                        user.gender.isEmpty ? 'Not provided' : user.gender,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('User ID'),
                      subtitle: Text(user.id.toString()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CartScreen(userId: user.id),
                  ),
                ),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('View my cart'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }
}
