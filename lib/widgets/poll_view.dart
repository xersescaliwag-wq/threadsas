import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:threads/core/formatters.dart';
import 'package:threads/models/poll.dart';

/// Poll options with vote shares. Tapping an option votes once, while the poll is open.
class PollView extends StatelessWidget {
  const PollView({super.key, required this.poll, required this.onVote});
  final Poll poll;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final total = poll.totalVotes;
    final canVote = poll.isOpen && !poll.hasVoted;
    final showResults = poll.hasVoted || !poll.isOpen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in poll.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: canVote ? () => onVote(option.id) : null,
              child: _OptionBar(
                label: option.label,
                share: total == 0 ? 0.0 : option.votesCount / total,
                selected: poll.myOptionId == option.id,
                showResults: showResults,
              ),
            ),
          ),
        Text(
          '${compactCount(total)} votes · ${poll.isOpen ? _timeLeft() : 'Final results'}',
          style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
        ),
      ],
    );
  }

  String _timeLeft() {
    final left = poll.endsAt.difference(DateTime.now());
    if (left.inDays >= 1) return '${left.inDays}d left';
    if (left.inHours >= 1) return '${left.inHours}h left';
    return '${left.inMinutes.clamp(1, 59)}m left';
  }
}

class _OptionBar extends StatelessWidget {
  const _OptionBar({
    required this.label,
    required this.share,
    required this.selected,
    required this.showResults,
  });
  final String label;
  final double share;
  final bool selected;
  final bool showResults;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? CupertinoColors.activeBlue : CupertinoColors.separator,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            if (showResults)
              FractionallySizedBox(
                widthFactor: share.clamp(0.0, 1.0).toDouble(),
                heightFactor: 1,
                child: Container(color: CupertinoColors.systemGrey5),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, color: CupertinoColors.label),
                    ),
                  ),
                  if (showResults)
                    Text(
                      '${(share * 100).round()}%',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}