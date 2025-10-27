import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/feed_post.dart';
import '../models/recommendation.dart';
import '../models/user_model.dart';

class RecommendationService {
  RecommendationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _feedPostsRef =>
      _firestore.collection('feed_posts');

  CollectionReference<Map<String, dynamic>> get _userInsightsRef =>
      _firestore.collection('user_insights');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  Future<Map<String, dynamic>> _loadInsights(String uid) async {
    final doc = await _userInsightsRef.doc(uid).get();
    return doc.data() ?? <String, dynamic>{};
  }

  Future<List<FeedRecommendation>> recommendFeedPosts({
    required UserProfile currentUser,
    int limit = 8,
  }) async {
    final insights = await _loadInsights(currentUser.uid);
    final metrics =
        (insights['metrics'] as Map<String, dynamic>? ?? const {});
    final authorViews =
        _toDoubleMap(metrics['feedAuthorViews'] as Map<String, dynamic>?);
    final locationViews =
        _toDoubleMap(metrics['locationViews'] as Map<String, dynamic>?);

    final snapshot = await _feedPostsRef.orderBy('createdAt', descending: true).limit(100).get();
    final now = DateTime.now();

    final recommendations = <FeedRecommendation>[];

    for (final doc in snapshot.docs) {
      final post = FeedPost.fromFirestore(doc);
      if (post.authorId == currentUser.uid) continue;

      final reasons = <String>[];
      var score = 0.0;

      if (post.createdAt != null) {
        final hours = now.difference(post.createdAt!).inHours;
        score += 2.0 * math.exp(-hours / 24.0);
        reasons.add('Fresh post');
      }

      final authorBoost = authorViews[post.authorId] ?? 0;
      if (authorBoost > 0) {
        score += 0.6 * math.log(authorBoost + 1);
        reasons.add('You interacted with ${post.authorName}');
      }

      final locationKey = post.location.toLowerCase();
      final locBoost = locationViews[locationKey] ?? 0;
      if (locBoost > 0) {
        score += 0.4 * math.log(locBoost + 1);
        reasons.add('Matches locations you follow');
      }

      if ((currentUser.location ?? '').isNotEmpty &&
          post.location.toLowerCase().contains(
              currentUser.location!.toLowerCase())) {
        score += 0.5;
        reasons.add('Near your preferred location');
      }

      if (score <= 0) {
        score = 0.1;
      }

      recommendations.add(
        FeedRecommendation(
          post: post,
          score: score,
          reasons: reasons,
        ),
      );
    }

    recommendations.sort(
      (a, b) => b.score.compareTo(a.score),
    );

    return recommendations.take(limit).toList();
  }

  Future<List<UserRecommendation>> recommendPartners({
    required UserProfile currentUser,
    required UserRole targetRole,
    int limit = 6,
  }) async {
    final insights = await _loadInsights(currentUser.uid);
    final metrics =
        (insights['metrics'] as Map<String, dynamic>? ?? const {});
    final userViews =
        _toDoubleMap(metrics['userViews'] as Map<String, dynamic>?);
    final authorViews =
        _toDoubleMap(metrics['feedAuthorViews'] as Map<String, dynamic>?);

    final snapshot =
        await _usersRef.where('role', isEqualTo: targetRole.key).limit(50).get();

    final recommendations = <UserRecommendation>[];

    for (final doc in snapshot.docs) {
      final profile = UserProfile.fromMap(doc.id, doc.data());
      if (profile.uid == currentUser.uid) continue;

      var score = 0.0;
      final reasons = <String>[];

      final viewBoost = userViews[profile.uid] ?? 0;
      if (viewBoost > 0) {
        score += 0.6 * math.log(viewBoost + 1);
        reasons.add('You viewed their profile earlier');
      }

      final authorBoost = authorViews[profile.uid] ?? 0;
      if (authorBoost > 0) {
        score += 0.5 * math.log(authorBoost + 1);
        reasons.add('You interact with their posts');
      }

      if ((currentUser.location ?? '').isNotEmpty &&
          (profile.location ?? '')
              .toLowerCase()
              .contains(currentUser.location!.toLowerCase())) {
        score += 0.4;
        reasons.add('Nearby location match');
      }

      if ((profile.role == UserRole.farmer &&
              currentUser.role == UserRole.shopkeeper) ||
          (profile.role == UserRole.shopkeeper &&
              currentUser.role == UserRole.farmer)) {
        score += 0.2;
      }

      if (score <= 0) score = 0.1;

      recommendations.add(
        UserRecommendation(
          profile: profile,
          score: score,
          reasons: reasons,
        ),
      );
    }

    recommendations.sort((a, b) => b.score.compareTo(a.score));
    return recommendations.take(limit).toList();
  }

  Map<String, double> _toDoubleMap(Map<String, dynamic>? raw) {
    if (raw == null) return const {};
    final map = <String, double>{};
    raw.forEach((key, value) {
      final asNum = value is num ? value.toDouble() : double.tryParse('$value');
      if (asNum != null) {
        map[key] = asNum;
      }
    });
    return map;
  }
}
