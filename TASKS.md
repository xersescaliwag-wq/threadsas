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

1. **No Material in `lib/`** — only `package:flutter/cupertino.dart`, `package:flutter/widgets.dart`,
   `package:flutter/services.dart` and the listed packages. Verify with `grep -rn material lib/` → empty.
2. **RLS on every table**, with explicit policies (already in `supabase/schema.sql`).
3. **Cupertino + `adaptive_platform_ui` only**; `CupertinoIcons` instead of `Icons`, `CupertinoPageRoute`
   instead of `MaterialPageRoute`, etc.
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

> **Code status:** Steps 4–17 are implemented — `flutter analyze` reports **0 errors and 0 warnings**
> (only info-level lints: the guide's deliberate `widgets.dart`/`services.dart` imports that Cupertino
> re-exports, plus 2 `use_null_aware_elements`). `grep -rn material lib/` is empty.
> The app is expected to run once `supabase/schema.sql` has been run in the SQL Editor.
| 18 | Testing checklist (static + database + 3-account manual run) | ☐ |
| 19 | Deployment (ghost-post Edge Function, store builds) | ◐ function file done · ☐ deploy + store |
| 20 | Troubleshooting (reference, no code) | ☐ reference |
| 21 | Optional: video player, deep links, link previews, GIF search, communities, IG cross-posting | 21.1-21.5 done A, 21.6 left |

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
- [ ] 21.6 Instagram cross-posting (Meta review; token in Vault)
- [ ] Suggested order: video → deep links → link previews → GIF search → communities → Instagram

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
| Store listings: deletion page, data safety, privacy policy, review notes | Step 19 |

## Progress log

**Steps 4–17 implemented** (all guide code transcribed, imports adapted from `threads_clone` → `threads`).
Files created: 44 under `lib/` plus the Step 15 SQL added to `supabase/schema.sql`.

Deviations from the guide, all deliberate and environment-driven:

| # | Change | Reason |
|---|---|---|
| 1 | `AdaptiveButton(...)` → `AdaptiveButton.child(...)` in `login_screen.dart`, `sign_up_screen.dart`, `profile_screen.dart` | Installed `adaptive_platform_ui 1.0.2` puts the custom-child form on the named `child` constructor; the guide targeted 0.1.111 where `child:` was accepted directly. Spinner behaviour preserved. |
| 2 | `minSize: 28` → `minimumSize: const Size(28, 28)` in `thread_card.dart` | `CupertinoButton.minSize` is deprecated in this Flutter SDK, and `minimumSize` takes a `Size?`. |
| 3 | Added `searchTopics()` to `thread_repository.dart` (+ imports) | Step 15 calls it; Step 5's repository didn't include it. |
| 4 | Added `deleteAllMine()` to `media_repository.dart` | Step 17 calls it before account deletion. |
| 5 | Added `search_topics` function to `supabase/schema.sql` | Step 15 says run it in the SQL Editor; keeping it with the rest of the schema. |
| 6 | `publishableKey:` instead of deprecated `anonKey:` in `main.dart` | `supabase_flutter` 2.x. |

Remaining info-level lints (35, no errors/warnings): mostly `unnecessary_import` because the guide
imports `package:flutter/widgets.dart` / `services.dart` alongside `cupertino.dart` (which re-exports
them) — kept deliberately for guide fidelity; 2 × `use_null_aware_elements`; 1 ×
`use_build_context_synchronously` (guide code in `sign_up_screen.dart`). New files written after the
guide (21.1–21.4) do not add any unnecessary imports.

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

## Definition of done

1. `flutter analyze` — no errors.
2. `grep -rn material lib/` — no output.
3. Every `public.*` table shows `rowsecurity = true`.
4. Step 18 manual table passes on two devices with three accounts.
5. Release builds upload successfully (TestFlight internal + Play internal track).
