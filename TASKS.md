# Threads Clone — Build Plan

Derived from the full guide ("Build a Threads Clone with Flutter, Supabase and adaptive_platform_ui",
Steps 1–21). Source files:

| Source | Contents | Format |
|---|---|---|
| `C:\Users\ferre\OneDrive\Documents\guide threads\part1.txt` | Steps 1–13 (Steps 10 and 11 appear twice) | PDF renamed to .txt |
| `C:\Users\ferre\OneDrive\Documents\guide threads\part2.txt` | Step 13 (continued) – Step 17 | PDF renamed to .txt |
| `C:\Users\ferre\OneDrive\Documents\guide threads\part3.txt` | Steps 18–21 | plain text |

Extracted plain text (readable copies) live in `%TEMP%\opencode\`: `guide_part1.md`, `guide_part2.md`.

## Project rules (apply to every task)

1. **Material is allowed in exactly one file.** `lib/core/adaptive.dart` imports
   `package:flutter/material.dart` under the `material.` prefix; no other file under `lib/` may.
   Verify: `grep -rln "package:flutter/material.dart" lib/` → `lib/core/adaptive.dart` alone.
2. **RLS on every table**, with explicit policies (already in `supabase/schema.sql`).
3. **`adaptive_platform_ui` plus this project's own `adaptive.dart` helpers**; `AppIcons` instead of
   `CupertinoIcons`, `adaptivePageRoute` instead of `CupertinoPageRoute`/`MaterialPageRoute`,
   `context.colors.*` instead of `CupertinoColors`, and the `Adaptive*` widgets in place of their
   `Cupertino*` counterparts. The UI should look like the platform it runs on.
4. Only the **publishable key** (`sb_publishable_…`) ships in the app; never `sb_secret_…`/`service_role`.

## Key decisions / corrections from the guide

| # | Item | Decision |
|---|---|---|
| D1 | Package name | Guide uses `threads_clone`; this project is `threads`. **Adapt all imports to `package:threads/…`** (no rename needed). |
| D2 | Steps 10 & 11 appear twice in the PDF | **Use the later copy of each.** Later Step 10 = `core/links.dart` + `widgets/thread_action_row.dart` + `widgets/thread_menu.dart`; later Step 11 = `ComposeScreen({replyTo, quoting, editing})`. |
| D3 | Step 13 in part1 stops after `profile_screen.dart` | Part 2 finishes it with `edit_profile_screen.dart`. |
| D4 | App only compiles after Step 17 | `main_shell.dart` imports Activity/Search/Settings screens; `thread_card.dart` imports TopicScreen. Keep the placeholder `app.dart` until Step 7, then expect analyzer errors until Step 17. |
| D5 | Model names | Guide uses `models/profile.dart`, `models/poll.dart`, `models/thread_post.dart` (`ThreadPost`), `models/app_notification.dart`, `models/topic_hit.dart` + `core/json.dart`. Align with these. |
| D6 | iOS Podfile | Set `platform :ios, '15.0'` (`adaptive_platform_ui` requirement). |
| D7 | `supabase_flutter` API | Use `publishableKey:` (not deprecated `anonKey:`) — already fixed in `lib/main.dart`. |

## Status board

| Step | Deliverable | Status |
|---|---|---|
| 1 | Supabase dashboard settings (email auth, site URL) | ☐ user-only |
| 2 | `supabase/schema.sql` (tables, triggers, RLS, storage, realtime, functions) | ☑ file written · ☐ not yet run in Supabase |
| 3 | Flutter project, packages, folders, platform permissions, test removed | ☑ done |
| 4 | `core/config.dart`, `core/formatters.dart`, `core/json.dart`, `main.dart`, 4 models | ☑ done |
| 5 | Repositories (7 files) | ☑ done |
| 6 | Riverpod providers (5 files) | ☑ done |
| 7 | Theme, app shell, navigation (4 files) | ☑ done |
| 8 | Sign up / log in / onboarding (3 files) | ☑ done |
| 9 | Home feed + shared widgets (7 files) | ☑ done |
| 10 | Thread actions, menu, links — **later copy** (3 files) | ☑ done |
| 11 | Compose screen — **later copy** (1 file) | ☑ done |
| 12 | Thread detail, nested replies, live updates (1 file) | ☑ done |
| 13 | Profile screen + edit profile (2 files) | ☑ done |
| 14 | Follow / follow requests / follow lists (4 files) | ☑ done |
| 15 | Search, topics, hashtag pages (4 files) + `search_topics` SQL | ☑ done |
| 16 | Activity / notifications with realtime (1 file) | ☑ done |
| 17 | Settings, block, mute, report, delete account (4 files) | ☑ done |
| 18 | Testing checklist (static + database + 3-account manual run) | ◐ static checks pass · ☐ manual run |

> **Code status:** Steps 4–17 are implemented, and the UI adapts to the platform it runs on
> (Material on Android, Cupertino ≤ iOS 18, Liquid Glass on iOS 26+ — see deviation 11).
> `flutter analyze` reports **0 errors and 0 warnings** (8 info-level lints: the guide's deliberate
> `widgets.dart`/`services.dart` imports that Cupertino re-exports, plus 2 `use_null_aware_elements`
> and 1 `use_build_context_synchronously`). `grep -rln "package:flutter/material.dart" lib/`
> returns `lib/core/adaptive.dart` and nothing else.
> The app is expected to run once `supabase/schema.sql` has been run in the SQL Editor.
> **Direct messages** (deviation 15) are a post-guide addition; the app needs the new
> "Direct messages" block of `supabase/schema.sql` (three tables, one function, one trigger,
> two policies each) before the Message button and the inbox work.

| 19 | Deployment (ghost-post Edge Function, store builds) | ◐ function file done · ☐ deploy + store |
| 20 | Troubleshooting (reference, no code) | ☐ reference |
| 21 | Optional: video player, deep links, link previews, GIF search, communities, IG cross-posting | ☑ 21.1–21.6 code done · ☐ IG setup is user-only |

---

## Step-by-step tasks

### Step 4 — finish configuration and models
- [x] `lib/core/json.dart` — `asInt`, `asDate`, `asStringList`
- [x] `lib/models/profile.dart` — align with guide (adds `name` getter, `author.name` usage)
- [x] `lib/models/poll.dart` — `Poll` + `PollOption` as the guide defines them
- [x] `lib/models/thread_post.dart` — `ThreadPost` (replaces my `thread.dart`); carries `author` (`Profile`), media, poll, quoted post
- [x] `lib/models/app_notification.dart` — align with guide
- [x] `lib/main.dart` — confirm imports `package:threads/…`
- [ ] Keep the placeholder `lib/app.dart` until Step 7

### Step 5 — data layer (repositories)
- [x] `lib/core/errors.dart` — map Supabase/Postgres errors to friendly messages
- [x] `lib/data/auth_repository.dart` — sign up/in/out, profile metadata
- [x] `lib/data/profile_repository.dart`
- [x] `lib/data/media_repository.dart` — uploads to `avatars/<uid>/…`, `thread-media/<uid>/…`
- [x] `lib/data/thread_repository.dart` — feeds, replies, likes, reposts, compose, search
- [x] `lib/data/social_repository.dart` — follow/unfollow/requests, block, mute, report
- [x] `lib/data/notification_repository.dart` — activity list, mark read, realtime stream

### Step 6 — state management (Riverpod)
- [x] `lib/providers/core_providers.dart` — session, current profile, repositories
- [x] `lib/providers/feed_providers.dart` — For you / Following feeds, pagination
- [x] `lib/providers/social_providers.dart` — follow state, profile data
- [x] `lib/providers/thread_providers.dart` — thread detail, replies, live updates
- [x] `lib/providers/notification_providers.dart` — unread count, activity

### Step 7 — theme, shell, navigation
- [x] `lib/core/navigation.dart`
- [x] `lib/app.dart` — real theme + root (replaces placeholder)
- [x] `lib/screens/auth/auth_gate.dart`
- [x] `lib/screens/shell/main_shell.dart` — Profile / Search / Compose / Activity / Home tabs

### Step 8 — authentication
- [x] `lib/core/messages.dart`
- [x] `lib/screens/auth/login_screen.dart`
- [x] `lib/screens/auth/sign_up_screen.dart` (unique username check + metadata)

### Step 9 — home feed and shared widgets
- [x] `lib/widgets/avatar.dart`
- [x] `lib/widgets/rich_content.dart` — tappable #hashtags and @mentions
- [x] `lib/widgets/media_grid.dart`
- [x] `lib/widgets/poll_view.dart`
- [x] `lib/widgets/quote_card.dart`
- [x] `lib/widgets/thread_card.dart` (imports `TopicScreen` — arrives in Step 15)
- [x] `lib/screens/home/home_screen.dart` — infinite scroll + pull to refresh

### Step 10 — thread actions (later copy)
- [x] `lib/core/links.dart` — `threadLink`, `copyThreadLink`
- [x] `lib/widgets/thread_action_row.dart` — like, repost, reply, quote, share
- [x] `lib/widgets/thread_menu.dart` — edit, delete, pin, hide like count, report, block/mute

### Step 11 — composer (later copy)
- [x] `lib/screens/compose/compose_screen.dart` — `({replyTo, quoting, editing})`, text ≤500,
      10 media items, polls (2–4 options + duration), reply controls, ghost posts (24 h)

### Step 12 — thread detail
- [x] `lib/screens/thread/thread_detail_screen.dart` — nested replies, realtime reload

### Step 13 — profiles
- [x] `lib/screens/profile/profile_screen.dart` — tabs (Threads / Replies / Reposts), pinned first,
      private-account notice, follow states, `showAppBar` flag
- [x] `lib/screens/profile/edit_profile_screen.dart` — avatar upload on save, username
      re-validation, accept pending requests when switching to public

### Step 14 — follow system
- [x] `lib/widgets/profile_row.dart`, `lib/widgets/small_button.dart`
- [x] `lib/screens/profile/follow_list_screen.dart`
- [x] `lib/screens/profile/follow_requests_screen.dart`

### Step 15 — discovery
- [x] `lib/models/topic_hit.dart`
- [x] `lib/providers/search_providers.dart`
- [x] `lib/screens/search/search_screen.dart` — People / Threads / Topics
- [x] `lib/screens/search/topic_screen.dart` (imported by `thread_card.dart`)

### Step 16 — activity
- [x] `lib/screens/activity/activity_screen.dart` — likes, replies, mentions, reposts, quotes,
      follows + requests, realtime, badge clears on open

### Step 17 — settings and safety
- [x] `lib/widgets/report_dialog.dart`
- [x] `lib/widgets/profile_menu.dart`
- [x] `lib/screens/settings/account_list_screen.dart` (followers/following/blocked/muted)
- [x] `lib/screens/settings/settings_screen.dart` — log out, private toggle, delete account
- [ ] After this step the whole app must compile.

### Step 18 — testing checklist
- [x] Static: `flutter analyze` clean; `grep -rn material lib/` empty
- [ ] Database: `select tablename, rowsecurity from pg_tables where schemaname = 'public'` → all `true`
- [ ] RLS impersonation test with 3 accounts (Ana/Ben/Cy) + the 10-case table
- [ ] 17-row manual test table (two devices + third account)
- [ ] `flutter build appbundle --release` / `flutter build ipa --release` when accounts are ready

### Step 19 — deployment
- [x] `supabase/functions/cleanup-expired/index.ts` (deletes files then rows; `x-cron-secret`)
- [ ] `supabase secrets set CRON_SECRET=…`, `supabase functions deploy cleanup-expired --no-verify-jwt`
- [ ] `pg_cron` + `pg_net`; schedule every 30 min; **do not** also run the Step 2 one-liner
- [ ] Replace `com.example` bundle id (Android `applicationId`/`namespace`, iOS `PRODUCT_BUNDLE_IDENTIFIER`)
- [ ] Turn Confirm email back on; Site URL to the real domain; remove test data
- [ ] Store requirements: deletion page, data-safety answers, privacy policy, review notes

### Step 20 — troubleshooting
Reference table only (404s from `/rest/v1/` URL, Material import leaks, empty lists vs RLS, storage
path 403, counter drift, realtime, release-only crashes).

### Step 21 — optional roadmap
- [x] 21.1 Video playback: `flutter pub add video_player` + `lib/widgets/video_player_view.dart`
- [x] 21.2 Deep links / magic links: `threads://login-callback` (Info.plist, Android intent
      filter, Supabase redirect allow-list, `signInWithOtp`)
- [x] 21.3 GIF search via Edge Function (key stays server-side) + `media_kinds` column
- [x] 21.4 Link previews via Edge Function (https-only, private-IP blocking, 100 KB cap, cache table)
- [x] 21.5 Communities (`communities`, `community_members`, `threads.community_id` + membership RLS; restrictive policies keep feeds clean)
- [x] 21.6 Instagram cross-posting (OAuth Edge Function, token in Supabase Vault, cross-post switch)
- [ ] Suggested order: video → deep links → link previews → GIF search → communities → Instagram
- [ ] 21.6 is code-complete but **user-only to enable**: Meta app + permissions review, secrets, deploy

---

## User-only tasks (outside the code)

| Task | When |
|---|---|
| Run `supabase/schema.sql` in the SQL Editor (once) | before Step 5 testing |
| Auth: Email on; Confirm email off while developing | Step 1 |
| Auth: Site URL = `http://localhost:3000` | Step 1 |
| Create 3 test accounts (Ana, Ben, Cy) | Step 18 |
| Create Supabase project values / rotate keys if needed | Step 19 |
| `openssl rand -hex 32` secret, `supabase login/link`, deploy function | Step 19 |
| Run the **Direct messages** block of `supabase/schema.sql` in the SQL Editor (once) | before testing the Message button / inbox |
| Make a Meta developer app, add the Instagram permissions, wait for review | 21.6 || `supabase secrets set META_APP_ID=... META_APP_SECRET=...`; deploy `instagram-oauth --no-verify-jwt` and `instagram-publish` | 21.6 |
| Store listings: deletion page, data safety, privacy policy, review notes | Step 19 |

## Progress log

**Steps 4–17 implemented** (all guide code transcribed, imports adapted from `threads_clone` → `threads`).
Files created: 44 under `lib/` plus the Step 15 SQL added to `supabase/schema.sql`.

**Platform-adaptive UI pass** (after Steps 4–17; deviations 11–13): `lib/core/adaptive.dart` gained
`materialAppTheme` (light/dark), `AppSpinner`, `AppRefreshView`, `AppColors` + the `context.colors`
extension, `AppIcons` (42 names), `adaptivePageRoute`, `AppListSection`, `AppListChevron`,
`AppSearchField`, `borderlessInputDecoration` and `showAppActionSheet`/`AppActionSheetItem`.
`lib/app.dart` now hands both Material themes to `AdaptiveApp`. 38 files were converted — `Cupertino*`
widgets to their `Adaptive*` equivalents and `CupertinoColors.*` to `context.colors.*` — so on Android
the app renders Material and on iOS it stays Cupertino/Liquid Glass. `flutter analyze` held at
0 errors / 0 warnings throughout. A first pass left 11 sites behind (see the bug-fix note below); all
are now converted, and `Cupertino*` appears outside `adaptive.dart` only as the imports themselves plus
`app.dart`'s intentional `CupertinoThemeData`.

**Feeds drawer + direct messages** (deviations 14–15, after the adaptive pass): Home's hand-rolled
drawer became the shell's real platform drawer (`AppDrawer`, `selectedFeedProvider`), the Home
segmented control was removed (the two feeds live in the drawer), and the app gained **direct
messages** — a schema block (3 tables + RLS + `start_conversation` + a preview trigger), a
repository/providers, a new `ChatScreen`, a real inbox, and a **Message** button on other people's
profiles. The inbox previously said only "Messages from people you follow will appear here". `flutter
analyze` still holds at 0 errors / 0 warnings / 8 infos.

Deviations from the guide, all deliberate and environment-driven:

| # | Change | Reason |
|---|---|---|
| 1 | `AdaptiveButton(...)` → `AdaptiveButton.child(...)` in `login_screen.dart`, `sign_up_screen.dart`, `profile_screen.dart` | Installed `adaptive_platform_ui 1.0.2` puts the custom-child form on the named `child` constructor; the guide targeted 0.1.111 where `child:` was accepted directly. Spinner behaviour preserved. |
| 2 | `minSize: 28` → `minimumSize: const Size(28, 28)` in `thread_card.dart` | `CupertinoButton.minSize` is deprecated in this Flutter SDK, and `minimumSize` takes a `Size?`. |
| 3 | Added `searchTopics()` to `thread_repository.dart` (+ imports) | Step 15 calls it; Step 5's repository didn't include it. |
| 4 | Added `deleteAllMine()` to `media_repository.dart` | Step 17 calls it before account deletion. |
| 5 | Added `search_topics` function to `supabase/schema.sql` | Step 15 says run it in the SQL Editor; keeping it with the rest of the schema. |
| 6 | `publishableKey:` instead of deprecated `anonKey:` in `main.dart` | `supabase_flutter` 2.x. |
| 7 | Bottom-nav `AdaptiveNavigationDestination(icon: 'house.fill', ...)` → `icon: PlatformInfo.isIOS26OrHigher() ? 'house.fill' : CupertinoIcons.house_fill` (same for each tab) in `main_shell.dart` | `AdaptiveNavigationDestination.icon` is `dynamic` and is read differently by each bar: the iOS 26+ native tab bar needs the SF Symbol *string*, but the iOS <26 Cupertino bar and the Android Material bar need an `IconData` (a string there maps through a tiny table, or to a plain circle on Android). Choosing per platform keeps every tab icon visible. App-bar actions are unaffected — `AdaptiveAppBarAction` already takes `iosSymbol` (iOS 26+) and `icon` (iOS <26/Android) separately, and all four sites set both. |
| 8 | Self-embed hint `quoted:threads!threads_quote_id_fkey(...)` → `quoted:threads!quote_id(...)` in `thread_repository.dart` (`_threadSelect`) | The quote embed is `threads → threads` (self-referential). PostgREST's hint-by-constraint-name (which its own PGRST201 error suggests) fails for self-references with `PGRST200 ... no matches were found`; hinting by the FK *column* (`quote_id`) resolves it. All non-self embeds keep their constraint-name hints (`threads_author_id_fkey`, `notifications_thread_id_fkey`), which work. Verified against the live REST API. |
| 9 | `uses-material-design: false` → `true` in `pubspec.yaml` | On Android there is no fixed chrome (`AdaptiveToolbarHost` only hosts it when `PlatformInfo.isIOS26OrHigher()`), so `AdaptiveScaffold` builds a Material `AppBar` (from `MaterialApp`, since `AdaptiveApp` only uses `CupertinoApp` when `PlatformInfo.isIOS`). That bar's automatic back button is Material's `Icons.arrow_back`, drawn from the **MaterialIcons** font. With the font excluded the chevron rendered as an empty/missing glyph on Android ("no proper icon"). Bundling the font does not pull `material.dart` into `lib/`, so the "no Material imports" rule still holds. Font changes need a **full rebuild**, not hot reload. |
| 10 | `threads_insert` policy dropped its `exists (select 1 from public.threads ...)` checks for `parent_id`/`quote_id`; added trigger `trg_threads_visible_refs` (function `public.threads_check_visible_refs()`, **security invoker**) on `public.threads` in `supabase/schema.sql` | A policy may not query the table it is defined on. `threads_insert`'s self-reference made Postgres raise `42P17 infinite recursion detected in policy for relation "threads"`, so **every** insert into `threads` failed (reproduced against the live project with a throwaway user, both with `return=representation` and `return=minimal`, top-level and reply). The two FK constraints (`threads_parent_id_fkey`, `threads_quote_id_fkey`) already guarantee the referenced rows exist; the new invoker trigger keeps the original intent (you may only reply to or quote a thread you are allowed to see) by letting the `threads_select` policy perform the visibility test — an invoker trigger gets RLS, whereas a policy cannot reference its own table and a security-definer helper would bypass RLS entirely. |
| 11 | **"No Material in `lib/`" relaxed.** `lib/core/adaptive.dart` is now the only file that imports `package:flutter/material.dart`, and it does so under the `material.` prefix. Everything else reaches Material through its exports: `materialAppTheme`, `AppSpinner`, `AppRefreshView`, `AppColors` + `context.colors`, `AppIcons`, `adaptivePageRoute`, `AdaptiveSegmentedControl`, `AppListSection`/`AppListChevron`, `AppSearchField`, `borderlessInputDecoration`, `AppActionSheetItem`/`showAppActionSheet`, `AdaptiveAlertDialog`/`AlertAction`. | Asked for a genuinely platform-adaptive UI: Material on Android, Cupertino on iOS ≤ 18, Liquid Glass on iOS 26+. That needs `MaterialApp`'s theme, `SegmentedButton`, `showModalBottomSheet`, `ListTile`, `Divider` and `Icons.*`, none of which the guide's Cupertino-only code uses. Confining the import to one file keeps the rule's *intent* (no Material scattered through the screens) while letting Android look like Android. `grep -rln "package:flutter/material.dart" lib/` still returns exactly one file. |
| 12 | **Every `Cupertino*` widget swapped for its adaptive counterpart**, across 27 files: `CupertinoActivityIndicator` → `AppSpinner`, `CupertinoSliverRefreshControl` → `AppRefreshView`, `CupertinoButton(.filled)` → `AdaptiveButton.child`, `CupertinoSwitch` → `AdaptiveSwitch`, `CupertinoTextField` → `AdaptiveTextField`, `CupertinoSearchTextField` → `AppSearchField`, `CupertinoSlidingSegmentedControl` → `AdaptiveSegmentedControl`, `CupertinoListTile`/`CupertinoListTileChevron`/`CupertinoListSection` → `AdaptiveListTile`/`AppListChevron`/`AppListSection`, `showCupertinoModalPopup`+`CupertinoActionSheet` → `showAppActionSheet`, `showCupertinoDialog`+`CupertinoAlertDialog` (with a text box) → `AdaptiveAlertDialog.inputShow`, `CupertinoPageRoute` → `adaptivePageRoute`, `CupertinoIcons.X` → `AppIcons.X`. | Each is the package's documented adaptive equivalent, so Android now renders Material buttons, switches, segmented controls and list rows. `adaptive_platform_ui` 1.0.2 ships **no** adaptive spinner, refresh control, route, action sheet, search field or grouped-list section, so `adaptive.dart` supplies those; `showAppActionSheet` and `AdaptiveAlertDialog.inputShow` preserve the existing `await`-a-choice and `await`-a-string call sites unchanged. |
| 13 | **All 109 `CupertinoColors.*` references → `context.colors.*`** (59 `const` markers removed, because the getters are runtime values). `AppColors` exposes the same names (`label`, `secondaryLabel`, `tertiaryLabel`, `separator`, `systemBackground`, `activeBlue`, `systemRed`, `systemGrey4/5/6`, …) and returns the Cupertino value on iOS and the matching `ColorScheme` token on Android. | With `MaterialApp` there is no `CupertinoTheme`, so `CupertinoDynamicColor` resolves against the *default light* Cupertino theme. On Android in dark mode every secondary label and separator therefore kept its light-mode gray and lost contrast against the dark surface. `context.colors.secondaryLabel` resolves to `onSurfaceVariant`/`outlineVariant`/`surfaceContainerHighest` instead, so greys, blues and semantic reds follow the active theme on Android and stay pixel-identical on iOS. |
| 14 | **Home feeds drawer rebuilt as a proper platform drawer.** Hand-rolled overlay (`Positioned.fill`) → `AdaptiveScaffold.drawer` with a new `AppDrawer` (Material `Drawer` on Android, Cupertino-style flat panel on iOS), plus `openAppDrawer`/`closeAppDrawer` helpers. Added `selectedFeedProvider` (`Notifier<int>`) to share the selected feed between Home and the drawer. Removed the four inert placeholders (+, pencil, heart/bookmark shortcut boxes, 'Ghost posts') and kept only the two functional feeds (For you/Following). | The old drawer was a non-animated custom overlay with no edge-swipe/draggable scrim (just a tap-to-close scrim). Using the scaffold's native drawer gives proper Material behavior on Android (slide-in, scrim fade, drag-to-open/close, edge swipe) and the same mechanics on iOS via the package's wrapper. Centralizing selection in a provider eliminates the tight coupling to `_drawerOpen`/local state and makes it easy to add more feeds later. |
| 15 | **Direct messages, added on request (not in the guide).** New `conversations`, `conversation_participants` and `messages` tables + RLS + the `start_conversation(uuid)` **security definer** function + the `messages_touch_conversation` **security definer** trigger, all in `supabase/schema.sql`; `lib/models/message.dart`, `lib/models/conversation.dart`, `lib/data/message_repository.dart`, `lib/providers/message_providers.dart`; `lib/screens/messages/chat_screen.dart` (new) and a rewritten inbox `lib/screens/messages/messages_screen.dart`; a **Message** button next to Follow on other people's profiles. | Asked for: open a profile → Follow + Message, send a message, and see the history in the inbox like any other thread. The box was previously a placeholder ('Messages from people you follow will appear here'). Design notes: a conversation is a **pair** (`user_a`/`user_b`, stored in canonical order, `unique`), so each pair maps to one row and the policies are plain column tests. A policy on `conversations` must not query `conversations` (deviation 10's `42P17` trap), so the `conversation_participants` policy delegates to the *conversations* policy — a different table — and messages do the same. The inbox is one query because the newest message is denormalised onto the conversation by the trigger; the read receipt is `conversation_participants.last_read_at`, so "unread" is a timestamp comparison with no count subquery. Rows are only ever created through the security-definer function (no client insert policy on `conversations`/`conversation_participants`), which also refuses to start a thread with somebody who has blocked you (or whom you blocked). |

Remaining info-level lints (**8**, no errors/warnings): 5 × `unnecessary_import` — the guide's deliberate
`package:flutter/widgets.dart` / `services.dart` imports alongside `cupertino.dart` (which re-exports
them), kept for guide fidelity in `login_screen.dart`, `sign_up_screen.dart` and
`edit_profile_screen.dart`; 2 × `use_null_aware_elements` (`profile_repository.dart`,
`thread_repository.dart`); 1 × `use_build_context_synchronously` (guide code in `sign_up_screen.dart`).
The adaptive-UI pass (deviations 11–13) rewrote 38 files; after it the analyzer flags those two
imports only in those three screens, so the total fell from 38 to 8.

### Bug fixes found while testing

- **Hand-rolled drawer replaced with native platform drawer.** Replaced the Home feeds overlay with `AdaptiveScaffold.drawer` + a new `AppDrawer` (Material `Drawer` on Android; Cupertino-style flat panel on iOS), added `selectedFeedProvider` (`Notifier<int>`) to share feed selection, and removed the four inert placeholders. This gives slide-in/scrim/drag/edge-swipe behavior and a cleaner, more maintainable drawer.
  1. The `CupertinoIcons.X` → `AppIcons.X` pass only rewrote names that already had an `AppIcons`
     getter, so `line_horizontal_3`, `add_circled`, `smiley`, `slider_horizontal_3`, `xmark`,
     `bookmark` and `eye` stayed as `CupertinoIcons`. (It stayed compiling, because
     `package:flutter/cupertino.dart` is imported everywhere, so nothing flagged it.)
  2. The text-field pass matched `CupertinoTextField(`, which does not match
     `CupertinoTextField.borderless(` — so the composer body in `compose_screen.dart` (the one inside
     `build`, not the helper) kept a raw Cupertino field.
  Fixed: added those 7 getters (`AppIcons` is now 42), added `borderlessInputDecoration` so the
  composer keeps its borderless look on Android without importing Material, and converted the field to
  `AdaptiveTextField` with `cupertinoDecoration: const BoxDecoration()` for iOS. **Lesson:** the check is
  `grep` over the whole tree for `Cupertino`, not a spot-check — a whitelist-based sweep silently skips
  whatever is not on the list.
- **Following/followers count looked stale after a follow.** The database triggers keep
  `profiles.following_count` / `followers_count` correct (verified in `schema.sql`), but the app only
  invalidated the *other* user's `profileByIdProvider`. The signed-in user's own profile stays mounted
  in the shell (`IndexedStack`), so its cached count never reloaded. `_toggleFollow`
  (`profile_screen.dart`) now also invalidates `profileByIdProvider(me)` plus the affected
  `followersProvider` / `followingListProvider` for both users. The two block entry points
  (`profile_menu.dart`, `thread_menu.dart`) do the same, because blocking deletes follow rows in both
  directions and so moves both profiles' counts.
- **`PGRST200` on every thread query.** The self-referential quote embed is now hinted by FK column
  (`quoted:threads!quote_id`) — see deviation 8.
- **"Something went wrong / infinite recursion in policy for relation 'threads'" when posting.** The
  `threads_insert` policy's `with check` queried `public.threads` itself, which Postgres forbids
  (`42P17`). It failed for a plain top-level post as well as a reply, with or without `RETURNING` —
  so posting never worked. Dropped the now-redundant self-checks (the FKs already enforce that the
  parent/quote exist) and moved the "you may only reference a thread you can see" rule into the
  `security invoker` trigger described in deviation 10. The guide's own printed policy has this bug
  (`tmp/pdfs/part1_extracted.txt` lines 1145–1152), so it is not a transcription slip.
  **Verified live** (2026-10-17, throwaway users on `dfccorjkvgvigzrpbiny`, all cleaned up):
  top-level / reply / quote inserts → `201`; reply to a nonexistent thread → `400 "The thread you
  are replying to no longer exists"` (the `threads_before_insert` trigger's message, which runs
  first and bypasses RLS so it catches genuinely missing parents); reply or quote of a private
  account's hidden post → `400 "The thread you are replying to is no longer available"`; and reads on
  `threads` returned `200` throughout — which is what proved the failure was insert-only.
- **Android back button showed no proper icon.** `pubspec.yaml` had `uses-material-design: false`, so
  the MaterialIcons font was not bundled. On Android `adaptive_platform_ui` renders a Material `AppBar`
  whose back button is `Icons.arrow_back`, which then had no glyph. Set to `true` (see deviation 9) —
  this only bundles a font asset; `lib/` still contains no Material imports. Rebuild the app fully
  (`flutter run` again) for the font to appear.
- **A reaction was missing from other screens, and re-reacting failed with "Something went wrong …
  already exists".** Reported from the live app: a post liked in one place looked unliked on the
  author's profile, and tapping that empty heart produced
  `23505 duplicate key value violates unique constraint "likes_pkey"`. Two separate causes:
  1. *Stale copies.* `MainShell` keeps every tab alive in an `IndexedStack` and each screen fetches (and
     caches) its own list of posts, so a `likedByMe` flag decided at fetch time never changed. Added
     `providers/post_state_provider.dart`: one `PostStateStore` (`Map<String, ThreadPost>`) that
     `ThreadCard._update` writes on every like / unlike / repost / reply / vote, and which every
     `ThreadCard` reads through `postStateProvider.select((all) => all[post.id])` — so one reaction
     shows in the feed, the profile, a hashtag page and the thread page at once, with no refetch and
     no per-screen wiring. It resets when the signed-in user changes (so likes never leak between
     accounts), and each pull-to-refresh clears it because a refresh re-reads the server's truth
     (`_FeedNotifier.refresh`, profile/topic/community/thread-detail `_refresh`).
  2. *Not idempotent.* `like()` / `repost()` / `votePoll()` were plain `insert`s, so any stale heart
     turned a second tap into a duplicate-key error. All three are now `upsert(..., ignoreDuplicates:
     true)`; the table PKs are `(thread_id, user_id)`, so the conflict is ignored and the row stays
     as-is.
  **Verified live** (2026-10-17, throwaway user, cleaned up): like → `201`, count `1`; second and third
  like → `201` with the count still `1` (no double count, no `409`); same for reposts; unlike → `204`,
  count `0`. Client paths carry the change through the shared store; `flutter analyze` stays at
  0 errors / 0 warnings.

### Step 18/19 artifacts

- `TESTING.md` — the Step 18 checklist (static checks, database RLS rules, 17-row manual table)
  ready to tick off as you work through it.
- `supabase/functions/cleanup-expired/index.ts` — Step 19 Edge Function; deletes the Storage files
  first, then the expired rows, so nothing is left in `thread-media` forever.
- `supabase/schema.sql` — the Step 19 cron schedule is included as a commented block, with a warning
  not to also run the Step 2 one-liner (two cleanups would race).
- Secret hygiene verified: `grep -rn "sb_secret|service_role" lib/` prints nothing; only
  `supabasePublishableKey` ships in the app.

### Step 21.1 — video playback

- `video_player: ^2.14.1` added to `pubspec.yaml`.
- `lib/widgets/video_player_view.dart` — the guide's player widget, verbatim (lazy load, tap to
  play/pause, spinner while loading, error icon when the video cannot load).
- `lib/screens/thread/media_viewer_screen.dart` — **addition, not printed by the guide.** The guide
  says "use it in the full-screen media view" and that tapping a video in the Step 9 grid "opens a
  page with this widget", but Step 9's `media_grid.dart` has no tap handling and Step 21.1 prints no
  viewer. This screen shows one photo or video full-screen (black background, back button).
- `lib/widgets/media_grid.dart` — its cells are now tappable and open `MediaViewerScreen` for that
  URL (the viewer's `kind` decides whether the player or the still image is shown; Step 21.3 later
  widened the grid to also mark GIFs). Everything else in the file is unchanged from the guide.

If you would rather keep Step 9's grid byte-identical to the guide, delete the two additions above
and the tap wiring; the app still compiles, but `VideoPlayerView` then has no entry point.

### Step 21.2 — deep links and magic links

Scheme chosen: **`threads`** (the guide printed `threadsclone` because its package was
`threads_clone`; this project is `threads`). The redirect address is therefore
**`threads://login-callback`**.

| File | Change |
|---|---|
| `ios/Runner/Info.plist` | Added `CFBundleURLTypes` → `CFBundleURLSchemes` → `threads` |
| `android/app/src/main/AndroidManifest.xml` | Added a `VIEW` / `BROWSABLE` intent filter for `threads://login-callback` inside `MainActivity` |
| `lib/data/auth_repository.dart` | New `sendSignInLink(email)` → `signInWithOtp(email, emailRedirectTo: 'threads://login-callback')` |
| `lib/screens/auth/login_screen.dart` | New "Email me a sign-in link" button calling `_sendLink()` |

**Architecture note:** the guide prints the `Supabase.instance.client.auth.signInWithOtp(...)` call
directly. Here it lives in `AuthRepository.sendSignInLink`, matching Step 5's repository pattern, and
the screen reaches it through `authRepositoryProvider`.

**You must do (dashboard):** in Supabase → Authentication → URL Configuration, add
`threads://login-callback` to the redirect addresses. Also note `supabase_flutter` receives the
callback itself, so no extra deep-link package is needed.

**You must do (device):** this only works on a real device or simulator where the scheme is
registered. Request a link, open the email on the same device, and check the app opens signed in. A
link opened on a different device should show the login screen, not an error.

### Step 21.3 — GIF search

Provider: **GIPHY** by default, with **Tenor** as an alternative. The function reads `GIPHY_API_KEY`
first and falls back to `TENOR_API_KEY`, so setting either secret is enough. The key is a secret and
never ships in the app; search runs behind the `gif-search` Edge Function, which also checks the
caller's token so only signed-in users can search.

| File | Purpose |
|---|---|
| `supabase/schema.sql` | Adds `threads.media_kinds text[]` with a check constraint in the Step 2 style (`cardinality <= 10` and every element in `array['image','video','gif']`). Because `threads` already exists, the column is added with `alter table … add column if not exists` and the constraint is dropped and re-added, so the script stays idempotent. Step 2's printed table is left untouched. A separate `grant update (media_kinds)` keeps the new column parallel to `media_urls` without editing Step 2's printed column grant. |
| `supabase/functions/gif-search/index.ts` | The Edge Function: verifies the caller's JWT via `admin.auth.getUser` (401 when missing or invalid), reads the provider key from secrets, searches GIPHY or Tenor, and returns `{ results: [{ id, preview_url, full_url, width, height }] }`. An empty query returns trending GIFs. |
| `lib/models/gif_result.dart` | `GifResult` — one `previewUrl` for the picker and one `fullUrl` for `media_urls`. |
| `lib/data/gif_repository.dart` | Calls `functions.invoke('gif-search', …)`. `GifSearchException` carries a readable reason, taken from the function's `{ "error": … }` body when present. |
| `lib/providers/core_providers.dart` | Adds `gifRepositoryProvider`. |
| `lib/screens/compose/gif_search_sheet.dart` | The picker: a search field (400 ms debounce, trending on open), a grid of previews, and `Navigator.pop(gif)` on a tap. Failures show a message instead of a blank grid. |
| `lib/screens/compose/compose_screen.dart` | New `_gifs` list and an "Add a GIF" button. GIFs are remote URLs, so they are **not** uploaded; their `fullUrl` is appended to `media_urls` and `'gif'` to `media_kinds`. Chosen GIFs appear in the media strip with a GIF tag and can be removed. |
| `lib/models/thread_post.dart` | Adds `mediaKinds` and `mediaKindAt(index)`, which uses the stored kind when present and falls back to the file extension (`mediaKindAt` keeps pre-21.3 posts working). |
| `lib/widgets/media_grid.dart` | Takes `kinds`; draws a play symbol for videos and a `GIF` badge for GIFs (no change for images). |
| `lib/screens/thread/media_viewer_screen.dart` | Takes a `kind` ('image'/'video'/'gif') instead of `isVideo`, and shows a `GIF` badge. A GIF is shown with `Image.network`, which Flutter animates on its own. |
| `lib/widgets/thread_card.dart` | Passes `kinds: post.mediaKinds` to `MediaGrid`. |

**You must do (secrets + deploy):**

```
supabase secrets set GIPHY_API_KEY=...      # or TENOR_API_KEY=...
supabase functions deploy gif-search
```

Deploy with JWT verification **ON** (the default). The function checks the token itself as well, so a
signed-out request returns 401 either way.

**Design notes:**

- **Why both providers:** I cannot know which key you will obtain, so the function supports either and
  keeps the code small (one adapter each). GIPHY's `fixed_width`/`downsized` and Tenor's
  `tinygif`/`gif` map to the same `preview_url`/`full_url` pair.
- **Full vs preview URL:** the full URL prefers a "downsized" GIF (still animated, much lighter than the
  original), so a feed of GIFs does not pull multi-megabyte files. The preview is a small still/animated
  image for the picker.
- **No new table:** `media_kinds` lives on `threads`, so the existing `threads` RLS policies cover it —
  there is no new RLS surface. Per Step 21's rules this feature still gets a second-account test and a
  Step 18 checklist line.
- **Older posts:** `media_kinds` defaults to `'{}'`, and `mediaKindAt` falls back to the extension, so
  posts made before this step are unaffected.

### Step 21.4 — link previews

The guide gives the spec, not the code, so this is written to the spec and to the project's existing
patterns (repository → provider → widget).

| File | Purpose |
|---|---|
| `supabase/schema.sql` | New `link_previews` table (`url` primary key, `title`, `description`, `image_url`, `fetched_at`) with RLS on and a single `select` policy for `authenticated`. No insert/update/delete policy, so only the function writes. |
| `supabase/functions/link-preview/index.ts` | The Edge Function: https-only, DNS-resolves every redirect hop and refuses private/local addresses, reads at most 100 KB, extracts `og:title`/`og:description`/`og:image` (with `twitter:` and `<title>` fallbacks), then caches the result. |
| `lib/models/link_preview.dart` | The preview value type (`isEmpty` when the page had nothing to show). |
| `lib/data/link_preview_repository.dart` | Calls `functions.invoke('link-preview', …)`. Every failure returns null — a preview is a nicety, so it never breaks the feed. |
| `lib/providers/link_preview_providers.dart` | `linkPreviewProvider` (family by URL). Riverpod caches per session; the server caches per week. |
| `lib/core/links.dart` | New `firstHttpsLink(text)` — finds the first https link, dropping trailing punctuation. |
| `lib/widgets/link_preview_card.dart` | The preview card: image, host, title (2 lines), description (2 lines); tapping opens the link externally. |
| `lib/widgets/thread_card.dart` | Renders `LinkPreviewCard(text: post.content)` under the post text. |

**Deploy it with JWT verification ON** (the default), so only signed-in users can call it (the guide
requires signed-in read access):

```
supabase functions deploy link-preview
```

Nothing else to configure — `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided to the
function automatically, and the table arrives with the rest of `supabase/schema.sql`.

Safety notes: the private-address check covers IPv4 loopback/private/link-local/CGNAT/reserved and the
IPv6 equivalents, including IPv4-mapped forms, and runs on **every** redirect hop *and* on the image
host. Redirects are followed manually (`redirect: "manual"`) precisely so each hop can be checked.

### Step 21.6 — Instagram cross-posting

The guide gives the spec, not the code ("needs a Meta developer app, a professional Instagram account,
and Meta's review"), so this is written to the spec and to the project's existing patterns. The whole
OAuth flow runs inside an Edge Function, and the account's access token is stored in **Supabase Vault**,
never in a table the app can read.

| File | Purpose |
|---|---|
| `supabase/schema.sql` | `instagram_accounts` (one row per connected user: `ig_user_id`, `page_id`, `username`, `token_secret_id`, `token_expires_at`) and `instagram_posts` (one row per cross-posted thread: `ig_media_id`, `status`, `error`). Both have RLS on and a single `select` owner policy; `revoke all` + column-level `grant select` means `token_secret_id` never reaches the app. Three `security definer` helpers — `set_instagram_credentials`, `get_instagram_token`, `disconnect_instagram` — are executable by `service_role` only, and are the only code that touches `vault.create_secret` / `vault.update_secret` / `vault.decrypted_secrets`. `create extension if not exists supabase_vault with schema vault;` is a no-op where Vault is already on (it is, by default, on every project). |
| `supabase/functions/instagram-oauth/index.ts` | Deploy **`--no-verify-jwt`** (Meta redirects the browser here with no Supabase token). Action `start` (requires a real user token) returns the Meta consent URL; the redirect lands back on the same function with `?code&state`, where the signed `state` (HMAC) identifies the user without a token; the function then exchanges the code for a long-lived user token, finds the Facebook Page with a linked Instagram professional account, and stores that Page's token in Vault. Action `disconnect` (user token) forgets the connection. On success it returns a plain page saying to return to the app — **no deep-link package is needed**, because the Instagram screen re-reads the connection when the app resumes. |
| `supabase/functions/instagram-publish/index.ts` | Deploy with JWT **ON** (default). Verifies the caller, checks the thread belongs to them, reads the token from Vault via `get_instagram_token`, then publishes to the Content Publishing API: one photo or video, or a carousel of 2–10. Videos (Reels) and video carousel items are polled until `FINISHED` before publishing. It records `status`/`ig_media_id`/`error` in `instagram_posts`. `action: "delete"` removes the copy. |
| `lib/models/instagram_account.dart` | `InstagramAccount` — no token field at all. |
| `lib/data/instagram_repository.dart` | `fetchAccount`, `beginConnect`, `disconnect`, `publish`, `deleteCopy`. `InstagramException` carries the function's readable reason. `deleteCopy` checks `instagram_posts` first and never throws. |
| `lib/providers/instagram_providers.dart` | `instagramAccountProvider` (the composer switch and the settings tile watch it). |
| `lib/providers/core_providers.dart` | Adds `instagramRepositoryProvider`. |
| `lib/screens/settings/instagram_screen.dart` | Connect / disconnect. Observes the app lifecycle and re-reads the connection on resume, so returning from the browser updates the screen. |
| `lib/screens/settings/settings_screen.dart` | New "Sharing" section with the Instagram row. |
| `lib/screens/compose/compose_screen.dart` | "Also post to Instagram" switch, shown only for a new top-level post that has a real photo or video **and** when an account is connected. After the thread is saved it calls `publish`; a failure shows "The Instagram copy failed: …" but **never blocks the Threads post**. |
| `lib/widgets/thread_menu.dart` | Before deleting a thread it removes the Instagram copy (best effort), then clears the `instagram_posts` row by cascade. |

**You must do (Meta + deploy):**

1. Create a Meta app (developers.facebook.com), add the **Instagram** product, and request
   `instagram_basic`, `instagram_content_publish`, `pages_show_list`, `pages_read_engagement`,
   `business_management`. `instagram_content_publish` needs Meta's review before it works for anyone
   but you — expect weeks.
2. Add this exact redirect URI in the Meta app (project ref is in `lib/core/config.dart`):
   `https://dfccorjkvgvigzrpbiny.supabase.co/functions/v1/instagram-oauth`
3. Set the secrets and deploy:
   ```
   supabase secrets set META_APP_ID=... META_APP_SECRET=...
   supabase functions deploy instagram-oauth --no-verify-jwt
   supabase functions deploy instagram-publish
   ```
4. Run the new `supabase/schema.sql` section in the SQL Editor (it is appended, so re-run just that
   block). No secret for the `state` signature is required — it falls back to the service role key — but
   you may set `INSTAGRAM_STATE_SECRET` to rotate it independently.

**Design notes:**

- **Why the secret never ships:** Meta's app secret is used only inside `instagram-oauth`; the access
  token is written straight to Vault and read only inside `instagram-publish`. The app's only Instagram
  reads are `instagram_accounts` (minus the token column) and `instagram_posts`.
- **Why a Page token:** the Content Publishing API publishes with the Facebook Page's token, not the
  user token, so the callback stores `page.access_token`.
- **Why the returned media id:** the guide asks for it "so a later delete can remove the Instagram copy
  too". The id is stored; note that Meta's API currently has **no endpoint to delete published media**,
  so the delete path tries anyway and otherwise tells the user to remove it in the Instagram app.
- **What Instagram accepts:** JPEG photos and MP4/MOV videos only. Other formats (PNG, WebP, GIF) get a
  clear "Instagram only accepts JPEG photos and MP4 or MOV videos." message instead of a silent failure.
- **New RLS surface:** both new tables have RLS on with an owner-only `select` policy and no write
  policies, so per Step 21's rules this gets a second-account test and Step 18 checklist lines.

## Direct messages (post-guide addition)

**Why:** the guide has no messaging feature; the Messages tab was a static placeholder. Requested:
open a profile → **Follow** and **Message** side by side; the Message button sends a message to that
person; the thread then appears in the inbox like any other conversation.

**Schema** (`supabase/schema.sql`, "Direct messages" block at the end):

- `conversations` — one row per **pair**. `user_a`/`user_b` are stored in canonical order
  (`unique (user_a, user_b)`), so each pair maps to exactly one row and the policies never need a
  self-reference (deviation 10's `42P17` trap). Also carries a denormalised copy of the newest
  message (`last_message_body`, `last_message_at`, `last_sender_id`) so the inbox is one query.
- `conversation_participants` — `(conversation_id, user_id)` + `last_read_at`, the read receipt.
- `messages` — `conversation_id`, `sender_id`, `body` (1–4000 chars), `created_at`.
- `start_conversation(p_other uuid) returns uuid` — **security definer**. Returns the existing thread
  for the pair or creates it (conversation + both participant rows). Refuses a self-conversation and
  refuses to start one when a block exists in either direction. Idempotent, so the app calls it
  unconditionally when the Message button is pressed.
- `messages_touch_conversation` — **security definer** trigger on `messages` that copies the new
  message onto its conversation.
- **RLS** on all three. `conversations`: `auth.uid() in (user_a, user_b)` (plain column test).
  `conversation_participants` and `messages`: `exists (select 1 from conversations c where c.id = …
  )`, i.e. the participant test is delegated to the *conversations* policy — a **different** table, so
  it cannot recurse. Plus `conversation_participants` may only be updated by its own `user_id`, and a
  message may only be inserted as yourself into a thread you are in. There is **no** client insert
  policy on `conversations`/`conversation_participants`: rows come only from the security-definer
  function.
- Realtime: `conversations` and `messages` are added to the `supabase_realtime` publication (inside an
  idempotent `do $$` block) for the live inbox and live chat.

**App:**

| File | Role |
|---|---|
| `lib/models/message.dart` | One message row. |
| `lib/models/conversation.dart` | Conversations row + participants embed; computes `isUnread` from `last_sender_id` vs my `last_read_at`. |
| `lib/data/message_repository.dart` | `conversations()` (single query, participants + profile embedded), `startConversation()`, `messages()`, `send()`, `markRead()`, `liveMessages()`, `liveConversations()`. |
| `lib/providers/message_providers.dart` | `conversationsProvider`, `conversationWithProvider`, `messagesProvider`, `liveMessagesProvider`, `liveInboxProvider`. |
| `lib/screens/messages/chat_screen.dart` | The thread: bubbles (mine right/`activeBlue`, theirs left), composer, realtime refresh, marks read. |
| `lib/screens/messages/messages_screen.dart` | The inbox: search, avatar + name + preview + time, bold row + blue dot when unread, empty state, pull to refresh. |
| `lib/screens/profile/profile_screen.dart` | `Edit profile` when it is me; otherwise **Follow** (filled) + **Message** (tinted) side by side. |

**Test it:** the sender and receiver must be **two different accounts** (two devices or one device and
the profile screen of another account). On the other person's profile tap **Message**, send text → the
bubble appears immediately and the conversation appears at the top of the Messages tab for **both**
accounts; with the other account's chat open, the incoming message appears without a manual refresh;
opening a thread clears the bold row/dot. Repeat the Step 18 second-account pass: a third account must
not see the conversation (`select` on `conversations` returns nothing), and messaging somebody who has
blocked you shows "you cannot message this account" instead of creating a row.

## Definition of done

1. `flutter analyze` — no errors.
2. `grep -rn material lib/` — no output.
3. Every `public.*` table shows `rowsecurity = true`.
4. Step 18 manual table passes on two devices with three accounts.
5. Release builds upload successfully (TestFlight internal + Play internal track).
