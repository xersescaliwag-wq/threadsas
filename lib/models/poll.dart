// lib/models/poll.dart
import 'package:threads/core/json.dart';

class PollOption {
  const PollOption({
    required this.id,
    required this.label,
    required this.position,
    required this.votesCount,
  });

  final String id;
  final String label;
  final int position;
  final int votesCount;

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] as String,
      label: json['label'] as String,
      position: asInt(json['position']),
      votesCount: asInt(json['votes_count']),
    );
  }
}

/// A poll attached to a thread. myOptionId is the option this user chose, if
/// any.
class Poll {
  Poll({required this.endsAt, required this.options, this.myOptionId});

  final DateTime endsAt;
  final List<PollOption> options;
  final String? myOptionId;

  bool get isOpen => endsAt.isAfter(DateTime.now());
  bool get hasVoted => myOptionId != null;
  int get totalVotes =>
      options.fold(0, (sum, option) => sum + option.votesCount);

  Poll copyWith({List<PollOption>? options, String? myOptionId}) {
    return Poll(
      endsAt: endsAt,
      options: options ?? this.options,
      myOptionId: myOptionId ?? this.myOptionId,
    );
  }
}

/// What the composer collects before a poll is published.
class PollDraft {
  const PollDraft({required this.options, required this.duration});

  final List<String> options;
  final Duration duration;
}
