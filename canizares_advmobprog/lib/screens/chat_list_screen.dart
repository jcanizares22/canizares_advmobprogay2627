import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.firebaseUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chats')),
        body: const Center(child: Text('Sign in with Firebase to use chat.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchText = value.trim().toLowerCase()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchText.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchText = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _chatService.usersStream(currentUserId: user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ChatListMessage(
                    icon: Icons.error_outline,
                    message: _loadErrorMessage(snapshot.error),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = (snapshot.data ?? []).where((otherUser) {
                  return otherUser.matchesChatSearch(_searchText);
                }).toList()..sort(_compareUsers);

                if (users.isEmpty) {
                  return _ChatListMessage(
                    icon: _searchText.isEmpty
                        ? Icons.people_outline
                        : Icons.search_off,
                    message: _searchText.isEmpty
                        ? 'No other chat profiles are available yet. New '
                              'registrations appear automatically. For older '
                              'accounts, sign in to each account once to sync '
                              'its profile.'
                        : 'No users match your search.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final otherUser = users[index];
                    final displayName = _displayName(otherUser);
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(_initials(displayName)),
                        ),
                        title: Text(displayName),
                        subtitle: Text(
                          otherUser.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openConversation(
                          context,
                          currentUser: user,
                          otherUser: otherUser,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _loadErrorMessage(Object? error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Firestore denied access to chat profiles. Deploy the latest '
          'firestore.rules to your Firebase project, then try again.';
    }
    return 'Could not load users: $error';
  }

  int _compareUsers(UserModel first, UserModel second) {
    return _displayName(
      first,
    ).toLowerCase().compareTo(_displayName(second).toLowerCase());
  }

  String _displayName(UserModel user) {
    final fullName = '${user.firstName} ${user.lastName}'.trim();
    if (fullName.isNotEmpty) return fullName;
    if (user.username.trim().isNotEmpty) return user.username.trim();
    return user.email.isNotEmpty ? user.email : 'User';
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return '${words.first.characters.first}${words.last.characters.first}'
        .toUpperCase();
  }

  Future<void> _openConversation(
    BuildContext context, {
    required User currentUser,
    required UserModel otherUser,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailScreen(
          currentUserId: currentUser.uid,
          currentUserEmail: currentUser.email ?? '',
          otherUser: otherUser,
        ),
      ),
    );
  }
}

class _ChatListMessage extends StatelessWidget {
  const _ChatListMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
