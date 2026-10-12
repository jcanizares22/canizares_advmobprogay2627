import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatMessageStatus { sending, sent, delivered, seen }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.status = ChatMessageStatus.sent,
  });

  final String id;
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final ChatMessageStatus status;

  factory ChatMessage.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return ChatMessage(
      id: document.id,
      senderId: data['senderId'] as String? ?? '',
      senderEmail: data['senderEmail'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      message: data['message'] as String? ?? '',
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: ChatMessageStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => ChatMessageStatus.sent,
      ),
    );
  }

  factory ChatMessage.pending({
    required String id,
    required String senderId,
    required String senderEmail,
    required String receiverId,
    required String message,
    required DateTime timestamp,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      senderEmail: senderEmail,
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
      status: ChatMessageStatus.sending,
    );
  }
}
