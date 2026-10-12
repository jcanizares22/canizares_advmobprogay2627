import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message.dart';
import '../models/user_model.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _chatProfiles =>
      _firestore.collection('chat_profiles');

  CollectionReference<Map<String, dynamic>> get _chatRooms =>
      _firestore.collection('chat_rooms');

  String conversationIdFor(String firstUserId, String secondUserId) {
    _requireDistinctUsers(firstUserId, secondUserId);
    final participantIds = [firstUserId, secondUserId]..sort();
    return participantIds.join('_');
  }

  Stream<List<UserModel>> usersStream({required String currentUserId}) {
    return _chatProfiles.snapshots().map((snapshot) {
      final registeredUsers = snapshot.docs.map(
        (document) =>
            UserModel.fromMap({...document.data(), 'uid': document.id}),
      );
      return registeredUsers
          .where((user) => user.uid != currentUserId)
          .toList();
    });
  }

  Future<void> ensureConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final participantIds = [currentUserId, otherUserId]..sort();
    final conversation = _chatRooms.doc(
      conversationIdFor(currentUserId, otherUserId),
    );

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(conversation);
      if (snapshot.exists) {
        final existingParticipants =
            snapshot.data()?['participantIds'] as List<dynamic>? ?? [];
        if (!existingParticipants.toSet().containsAll(participantIds) ||
            existingParticipants.length != participantIds.length) {
          throw StateError('The conversation has invalid participants.');
        }
      } else {
        transaction.set(conversation, {
          'participantIds': participantIds,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  String newMessageId(String conversationId) {
    return _messages(conversationId).doc().id;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    _requireDistinctUsers(senderId, receiverId);
    final currentUser = _auth.currentUser;
    if (currentUser?.uid != senderId) {
      throw StateError('The signed-in user cannot send as another user.');
    }

    await _messages(conversationId).doc(messageId).set({
      'senderId': senderId,
      'senderEmail': currentUser?.email ?? '',
      'receiverId': receiverId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'status': ChatMessageStatus.sent.name,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(
    String conversationId,
  ) {
    return _messages(
      conversationId,
    ).orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> markMessagesDelivered({
    required String conversationId,
    required String currentUserId,
    required Iterable<String> messageIds,
  }) {
    return _updateMessageStatuses(
      conversationId: conversationId,
      currentUserId: currentUserId,
      messageIds: messageIds,
      nextStatus: ChatMessageStatus.delivered,
      allowedStatuses: const {ChatMessageStatus.sent},
    );
  }

  Future<void> markMessagesSeen({
    required String conversationId,
    required String currentUserId,
    required Iterable<String> messageIds,
  }) {
    return _updateMessageStatuses(
      conversationId: conversationId,
      currentUserId: currentUserId,
      messageIds: messageIds,
      nextStatus: ChatMessageStatus.seen,
      allowedStatuses: const {
        ChatMessageStatus.sent,
        ChatMessageStatus.delivered,
      },
    );
  }

  CollectionReference<Map<String, dynamic>> _messages(String conversationId) =>
      _chatRooms.doc(conversationId).collection('messages');

  Future<void> _updateMessageStatuses({
    required String conversationId,
    required String currentUserId,
    required Iterable<String> messageIds,
    required ChatMessageStatus nextStatus,
    required Set<ChatMessageStatus> allowedStatuses,
  }) async {
    if (_auth.currentUser?.uid != currentUserId) {
      throw StateError("The signed-in user cannot update another user's chat.");
    }

    final messages = _messages(conversationId);
    for (final idChunk in _chunks(messageIds, 450)) {
      final documents = await Future.wait(
        idChunk.map((id) => messages.doc(id).get()),
      );
      final eligibleDocuments = documents.where((document) {
        final data = document.data();
        if (!document.exists || data == null) return false;
        final status = ChatMessageStatus.values.firstWhere(
          (candidate) => candidate.name == data['status'],
          orElse: () => ChatMessageStatus.sending,
        );
        return data['receiverId'] == currentUserId &&
            allowedStatuses.contains(status);
      });
      final batch = _firestore.batch();
      if (eligibleDocuments.isNotEmpty) {
        for (final document in eligibleDocuments) {
          batch.update(document.reference, {'status': nextStatus.name});
        }
        await batch.commit();
      }
    }
  }

  Iterable<List<T>> _chunks<T>(Iterable<T> values, int size) sync* {
    var chunk = <T>[];
    for (final value in values) {
      chunk.add(value);
      if (chunk.length == size) {
        yield chunk;
        chunk = <T>[];
      }
    }
    if (chunk.isNotEmpty) yield chunk;
  }

  void _requireDistinctUsers(String firstUserId, String secondUserId) {
    if (firstUserId.isEmpty || secondUserId.isEmpty) {
      throw ArgumentError('Both chat participant IDs are required.');
    }
    if (firstUserId == secondUserId) {
      throw ArgumentError('You cannot start a chat with yourself.');
    }
  }
}
