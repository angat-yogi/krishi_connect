import 'package:cloud_firestore/cloud_firestore.dart';

class ChatThread {
  const ChatThread({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.lastMessage,
    this.updatedAt,
    this.pendingParticipants = const [],
    this.blockedBy = const [],
  });

  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String? lastMessage;
  final DateTime? updatedAt;
  final List<String> pendingParticipants;
  final List<String> blockedBy;

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
      pendingParticipants:
          _stringList(data['pendingParticipants'] ?? const <String>[]),
      blockedBy: _stringList(data['blockedBy'] ?? const <String>[]),
    );
  }

  bool isPendingFor(String uid) => pendingParticipants.contains(uid);

  bool isBlockedFor(String uid) => blockedBy.contains(uid);

  bool get isBlocked => blockedBy.isNotEmpty;

  String otherParticipant(String uid) {
    return participants.firstWhere(
      (participant) => participant != uid,
      orElse: () => uid,
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

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}
