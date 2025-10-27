import 'package:cloud_firestore/cloud_firestore.dart';

class ChatThread {
  const ChatThread({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.lastMessage,
    this.updatedAt,
  });

  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String? lastMessage;
  final DateTime? updatedAt;

  factory ChatThread.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatThread(
      id: doc.id,
      participants:
          (data['participants'] as List<dynamic>? ?? []).cast<String>(),
      participantNames: (data['participantNames'] as Map<String, dynamic>? ??
              const <String, dynamic>{})
          .map((key, value) => MapEntry(key, value as String)),
      lastMessage: data['lastMessage'] as String?,
      updatedAt: _dateTimeFrom(data['updatedAt']),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: _dateTimeFrom(data['createdAt']),
    );
  }
}

DateTime? _dateTimeFrom(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
