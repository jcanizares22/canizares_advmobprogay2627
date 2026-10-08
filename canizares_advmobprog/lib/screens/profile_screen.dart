import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editUsername(BuildContext context, UserModel user) async {
    final auth = context.read<AuthProvider>();
    final controller = TextEditingController(text: user.username);
    final username = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update username'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Username',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (username == null || username.isEmpty || !context.mounted) return;
    final succeeded = await auth.updateUsername(username);
    if (!context.mounted) return;
    _showResult(context, succeeded, 'Username updated.');
  }

  Future<List<String>?> _requestPasswordChange(BuildContext context) {
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    return showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            TextField(
              controller: newPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, [
              currentPassword.text,
              newPassword.text,
            ]),
            child: const Text('Update'),
          ),
        ],
      ),
    ).whenComplete(() {
      currentPassword.dispose();
      newPassword.dispose();
    });
  }

  Future<String?> _requestCurrentPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm account deletion'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Delete account'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your Firebase account and profile data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final password = await _requestCurrentPassword(context);
    if (password == null || !context.mounted) return;
    final succeeded = await auth.deleteAccount(currentPassword: password);
    if (!context.mounted) return;
    _showResult(context, succeeded, 'Account deleted.');
  }

  Future<void> _changePassword(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final values = await _requestPasswordChange(context);
    if (values == null || !context.mounted) return;
    if (values[1].length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password must be at least 8 characters.'),
        ),
      );
      return;
    }
    final succeeded = await auth.resetPasswordFromCurrentPassword(
      currentPassword: values[0],
      newPassword: values[1],
    );
    if (!context.mounted) return;
    _showResult(context, succeeded, 'Password updated.');
  }

  Future<void> _resetPassword(BuildContext context, String email) async {
    final auth = context.read<AuthProvider>();
    final succeeded = await auth.resetPassword(email);
    if (!context.mounted) return;
    _showResult(context, succeeded, 'Password reset email sent.');
  }

  Future<void> _signOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true || !context.mounted) return;
    final auth = context.read<AuthProvider>();
    final succeeded = await auth.signOut();
    if (!context.mounted) return;
    if (!succeeded) _showResult(context, false, 'Unable to sign out.');
  }

  void _showResult(
    BuildContext context,
    bool succeeded,
    String successMessage,
  ) {
    if (!context.mounted) return;
    final message = succeeded
        ? successMessage
        : context.read<AuthProvider>().errorMessage ?? 'The request failed.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: auth.isLoading || auth.isInitializing
              ? const CircularProgressIndicator()
              : const Text('Profile information is unavailable.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 42,
            child: Text(
              user.username.isEmpty ? '?' : user.username[0].toUpperCase(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.username,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(user.email, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                _ProfileField(
                  label: user.loginType == LoginType.firebase
                      ? 'Firebase UID'
                      : 'DummyJSON user ID',
                  value: user.uid,
                ),
                _ProfileField(
                  label: 'Login type',
                  value: user.loginType == LoginType.firebase
                      ? 'Firebase Authentication'
                      : 'DummyJSON',
                ),
                _ProfileField(label: 'Username', value: user.username),
                _ProfileField(label: 'Email', value: user.email),
                _ProfileField(label: 'First name', value: user.firstName),
                _ProfileField(label: 'Last name', value: user.lastName),
                _ProfileField(
                  label: 'Age',
                  value: user.age == 0 ? 'Not provided' : '${user.age}',
                ),
                _ProfileField(
                  label: 'Contact number',
                  value: user.contactNumber.isEmpty
                      ? 'Not provided'
                      : user.contactNumber,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Browse products'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CartScreen(userId: user.uid)),
            ),
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('View my cart'),
          ),
          if (user.loginType == LoginType.firebase) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: auth.isLoading
                  ? null
                  : () => _editUsername(context, user),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit username'),
            ),
            OutlinedButton.icon(
              onPressed: auth.isLoading
                  ? null
                  : () => _changePassword(context),
              icon: const Icon(Icons.password_outlined),
              label: const Text('Update password'),
            ),
            OutlinedButton.icon(
              onPressed: auth.isLoading
                  ? null
                  : () => _resetPassword(context, user.email),
              icon: const Icon(Icons.mark_email_read_outlined),
              label: const Text('Send password reset email'),
            ),
            OutlinedButton.icon(
              onPressed: auth.isLoading ? null : () => _deleteAccount(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete account'),
            ),
          ],
          TextButton.icon(
            onPressed: auth.isLoading ? null : () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      subtitle: Text(value.isEmpty ? 'Not provided' : value),
    );
  }
}
