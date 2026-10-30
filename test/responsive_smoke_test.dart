import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:threads/core/adaptive.dart';
import 'package:threads/models/profile.dart';
import 'package:threads/models/thread_post.dart';
import 'package:threads/providers/core_providers.dart';
import 'package:threads/widgets/media_grid.dart';
import 'package:threads/widgets/thread_card.dart';

Widget _app(Widget child) => CupertinoApp(home: Center(child: child));

/// Loose constraints, the way a Column lays out its children.
Widget _loose(double width, Widget child) =>
    SizedBox(width: width, child: Align(alignment: Alignment.topLeft, child: child));

final _author = const Profile(
  id: 'u1',
  username: 'wandering_soul',
  displayName: 'Wandering Soul',
  bio: '',
  avatarUrl: null,
  website: null,
  isPrivate: false,
  isVerified: true,
  followersCount: 0,
  followingCount: 0,
  threadsCount: 0,
);

final _post = ThreadPost(
  id: 't1',
  author: _author,
  content: 'A short post used to check the card layout.',
  textFormatting: const {},
  mediaUrls: const [],
  mediaKinds: const [],
  music: null,
  parentId: null,
  rootId: null,
  communityId: null,
  quoted: null,
  hashtags: const [],
  mentions: const [],
  replyControl: ReplyControl.everyone,
  hideLikeCount: false,
  isPinned: false,
  expiresAt: null,
  likeCount: 3,
  replyCount: 1,
  repostCount: 0,
  quoteCount: 0,
  createdAt: DateTime(2026, 10, 30, 8),
  editedAt: null,
  poll: null,
  likedByMe: false,
  repostedByMe: false,
);

void main() {
  testWidgets('phones are untouched: child fills the width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    await tester.pumpWidget(
      _app(
        ResponsiveContent(
          child: Container(key: const Key('c'), color: const Color(0xFF00FF00)),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('c'))).width, 390);
  });

  testWidgets('wide screens cap the column at 600 and center it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    await tester.pumpWidget(
      _app(
        ResponsiveContent(
          child: Container(key: const Key('c'), color: const Color(0xFF00FF00)),
        ),
      ),
    );
    final size = tester.getSize(find.byKey(const Key('c')));
    expect(size.width, 600);
    expect(tester.getCenter(find.byKey(const Key('c'))).dx, 500);
  });

  testWidgets('media cells stay 140 on phones and grow on tablets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      _app(_loose(300, MediaGrid(urls: const ['https://example.com/a.png']))),
    );
    expect(tester.getSize(find.byType(Image)).width, 140);

    await tester.binding.setSurfaceSize(const Size(800, 800));
    await tester.pumpWidget(
      _app(_loose(520, MediaGrid(urls: const ['https://example.com/a.png']))),
    );
    expect(tester.getSize(find.byType(Image)).width, 200);
  });

  testWidgets('thread byline fits on a 320 pt phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserIdProvider.overrideWithValue('me')],
        child: material.MaterialApp(
          home: material.Scaffold(
            body: ThreadCard(post: _post, onChanged: (_) {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // The name must keep a usable width instead of collapsing to an ellipsis.
    expect(tester.getSize(find.text('Wandering Soul')).width, greaterThan(60));
  });

  testWidgets('thread byline survives a 390 pt phone at 1.3x text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserIdProvider.overrideWithValue('me')],
        child: material.MaterialApp(
          home: material.MediaQuery(
            data: const material.MediaQueryData(
              textScaler: TextScaler.linear(1.3),
            ),
            child: material.Scaffold(
              body: ThreadCard(post: _post, onChanged: (_) {}),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.text('Wandering Soul')).width,
      greaterThan(80),
    );
  });
}
