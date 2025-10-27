import 'package:cloud_firestore/cloud_firestore.dart';

enum EngagementType {
  screenView,
  feedView,
  feedInteraction,
  profileView,
  searchSelection,
  messageOpen,
  orderPlaced,
  follow,
}

extension EngagementTypeX on EngagementType {
  String get key => name;
}

enum EngagementTargetType {
  screen,
  feedPost,
  user,
  product,
  order,
  search,
}

extension EngagementTargetTypeX on EngagementTargetType {
  String get key => name;
}

class AnalyticsService {
  AnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('engagement_events');

  CollectionReference<Map<String, dynamic>> get _userInsightsRef =>
      _firestore.collection('user_insights');

  Future<void> logEngagement({
    required String userId,
    required EngagementType type,
    required EngagementTargetType targetType,
    required String targetId,
    Map<String, dynamic>? metadata,
    Map<String, num>? insightIncrements,
    DateTime? occurredAt,
  }) async {
    final eventPayload = <String, dynamic>{
      'userId': userId,
      'type': type.key,
      'targetType': targetType.key,
      'targetId': targetId,
      'createdAt': FieldValue.serverTimestamp(),
      if (occurredAt != null) 'occurredAt': Timestamp.fromDate(occurredAt),
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    };

    await _eventsRef.add(eventPayload);
    await _updateInsights(
      userId: userId,
      type: type,
      targetType: targetType,
      targetId: targetId,
      metadata: metadata,
      insightIncrements: insightIncrements,
    );
  }

  Future<void> _updateInsights({
    required String userId,
    required EngagementType type,
    required EngagementTargetType targetType,
    required String targetId,
    Map<String, dynamic>? metadata,
    Map<String, num>? insightIncrements,
  }) async {
    final update = <String, dynamic>{
      'userId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final increments = <String, FieldValue>{};

    void addIncrement(String key, num value) {
      if (key.isEmpty) return;
      increments[key] = FieldValue.increment(value);
    }

    switch (type) {
      case EngagementType.feedView:
        addIncrement('metrics.feedViews.total', 1);
        break;
      case EngagementType.feedInteraction:
        addIncrement('metrics.feedInteractions.total', 1);
        break;
      case EngagementType.profileView:
        addIncrement('metrics.profileViews.total', 1);
        break;
      case EngagementType.searchSelection:
        addIncrement('metrics.searchSelections.total', 1);
        break;
      case EngagementType.messageOpen:
        addIncrement('metrics.messageOpens.total', 1);
        break;
      case EngagementType.orderPlaced:
        addIncrement('metrics.orders.total', 1);
        break;
      case EngagementType.follow:
        addIncrement('metrics.follows.total', 1);
        break;
      case EngagementType.screenView:
        addIncrement(
            'metrics.screenViews.${metadata?['screenName'] ?? 'unknown'}', 1);
        break;
    }

    if (targetType == EngagementTargetType.feedPost &&
        metadata != null &&
        metadata['authorId'] != null) {
      addIncrement(
        'metrics.feedAuthorViews.${metadata['authorId']}',
        1,
      );
    }

    if (metadata != null && metadata['locationKey'] != null) {
      addIncrement(
        'metrics.locationViews.${metadata['locationKey']}',
        1,
      );
    }

    if (targetType == EngagementTargetType.user && targetId.isNotEmpty) {
      addIncrement('metrics.userViews.$targetId', 1);
    }

    if (insightIncrements != null && insightIncrements.isNotEmpty) {
      insightIncrements.forEach((key, value) {
        addIncrement('metrics.$key', value);
      });
    }

    if (increments.isNotEmpty) {
      update.addAll(increments);
    }

    await _userInsightsRef.doc(userId).set(
          update,
          SetOptions(merge: true),
        );
  }
}
