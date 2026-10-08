import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _updateUsername(BuildContext context, AuthProvider auth) async {
    final controller = TextEditingController(text: auth.user?.username ?? '');
    final username = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update username'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Username'),
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
    _showResult(context, auth, succeeded, 'Username updated.');
  }

  Future<void> _deleteAccount(BuildContext context, AuthProvider auth) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This permanently deletes your account and profile.'),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
    if (password == null || !context.mounted) return;
    final succeeded = await auth.deleteAccount(currentPassword: password);
    if (!context.mounted) return;
    _showResult(context, auth, succeeded, 'Account deleted.');
  }

  Future<void> _signOut(BuildContext context, AuthProvider auth) async {
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
    final succeeded = await auth.signOut();
    if (!context.mounted) return;
    if (succeeded) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _showResult(context, auth, false, 'Unable to sign out.');
    }
  }

  void _showResult(
    BuildContext context,
    AuthProvider auth,
    bool succeeded,
    String successMessage,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? successMessage
              : auth.errorMessage ?? 'The request failed.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle the application theme'),
            value: theme.isDarkMode,
            onChanged: theme.toggleTheme,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Account information'),
            subtitle: Text(user?.email ?? 'No signed-in account'),
          ),
          if (user != null && user.loginType == LoginType.firebase)
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(user.username),
              subtitle: const Text('Username'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: auth.isLoading
                  ? null
                  : () => _updateUsername(context, auth),
            ),
          if (user?.loginType == LoginType.firebase)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete account'),
              enabled: !auth.isLoading,
              onTap: auth.isLoading ? null : () => _deleteAccount(context, auth),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            enabled: user != null && !auth.isLoading,
            onTap: user == null || auth.isLoading
                ? null
                : () => _signOut(context, auth),
          ),
        ],
      ),
    );
  }
}
