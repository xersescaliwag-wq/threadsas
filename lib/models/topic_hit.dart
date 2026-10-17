// lib/models/topic_hit.dart
/// A topic suggestion: the tag without the # and how many threads use it.
class TopicHit {
  const TopicHit({required this.tag, required this.uses});
  final String tag;
  final int uses;
}
