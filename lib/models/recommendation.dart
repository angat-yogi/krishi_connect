import 'feed_post.dart';
import 'user_model.dart';

class FeedRecommendation {
  const FeedRecommendation({
    required this.post,
    required this.score,
    this.reasons = const [],
  });

  final FeedPost post;
  final double score;
  final List<String> reasons;
}

class UserRecommendation {
  const UserRecommendation({
    required this.profile,
    required this.score,
    this.reasons = const [],
  });

  final UserProfile profile;
  final double score;
  final List<String> reasons;
}
