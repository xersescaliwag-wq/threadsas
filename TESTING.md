# Threads — Step 18 Testing Checklist

Three parts: static checks, database rules, then a manual run with at least three accounts.
Run the static and database checks first, so a failure is easy to trace.

## 18.1 Static checks

From the project root:

```
flutter analyze
grep -rn "material" lib/
```

- `flutter analyze` — **no errors**. (Current state: 0 errors, 0 warnings, 35 info-level lints.)
- The grep must print **nothing**. Your code never imports Material; `adaptive_platform_ui` does, for
  its Android widgets, so the grep only looks at `lib/`.

The guide adds no tests, so `flutter test` has nothing to run unless you write some.

## 18.2 Database checks

### RLS is on everywhere

Run in the SQL Editor — every row must show `true`:

```sql
select tablename, rowsecurity from pg_tables
where schemaname = 'public' order by tablename;
```

### Rules as a real user would meet them

The SQL Editor runs as an administrator, which bypasses RLS, so the test has to impersonate a user.
Create three accounts in the app first: **Ana, Ben and Cy**. Copy their ids from the `profiles`
table, then run this with the placeholders replaced:

```sql
begin;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '<ben-id>', 'role', 'authenticated')::text,
  true
);

-- Ana is public and Ben follows her: expect her threads.
-- Ana is private and Ben does not follow her: expect 0.
select count(*) as visible_to_ben from public.threads where author_id = '<ana-id>';

-- Ben must not change his own verified badge. Expect a permission error.
update public.profiles set is_verified = true where id = '<ben-id>';
rollback;
```

Repeat with the ids switched to cover each case. The `rollback` undoes anything that got through, so
the test leaves no data behind.

| Case | Expected result |
|---|---|
| A stranger reads a private account's threads | Zero rows |
| A follower reads a private account's threads | Rows, once the follow is accepted |
| A pending follow request | The threads stay hidden |
| Either side of a block reads the other's threads | Zero rows |
| A user edits another user's profile | Error |
| A user sets `is_verified` or any counter | Error (the column grant from Step 2 forbids it) |
| A user reads another user's notifications | Zero rows |
| A user reads who reported them | Zero rows (reports are visible only to the reporter) |
| A user uploads to another user's storage folder | Error |
| An expired ghost post | Hidden from every feed and search |

## 18.3 Manual run

Use two devices or simulators signed in as **Ana** and **Ben**, plus a third account **Cy** for the
deletion test.

| Area | Test | Expected | Done |
|---|---|---|---|
| Sign up | Create a new account with a username and a name | A profile row appears, with counters at 0 | ☐ |
| Sign up | Use a username that is already taken | The app says it is taken, and nothing is saved | ☐ |
| Post | Publish a thread with a photo, a #hashtag and an @mention | It appears at the top of For you on both devices | ☐ |
| Post | Publish a poll with two options and a duration | Votes update the counts | ☐ |
| Post | Turn on Disappears in 24 hours and post | It shows at once, and later disappears from every feed | ☐ |
| Post | Pin a post, then pin a second one | The first pin is replaced | ☐ |
| Thread | Like, unlike, repost, undo repost, quote | Each change shows at once and survives a restart | ☐ |
| Thread | Reply, then reply to the reply | Replies nest and the reply count rises | ☐ |
| Thread | Edit a post | The Edited label appears | ☐ |
| Thread | Delete your own post | It leaves the feed and the database | ☐ |
| Live | Like from Ben's account while Ana watches the thread | Ana's count updates within a few seconds, no refresh | ☐ |
| Follow | Follow a private account, then accept it | Status changes from pending to accepted | ☐ |
| Search | People, Threads and Topics modes | Each finds the expected rows | ☐ |
| Activity | Like, reply and follow from Ben's account | Ana sees each row, and the badge clears when she opens the tab | ☐ |
| Safety | Mute, unmute, block, unblock, report | Each takes effect at once, and the report row appears in `reports` | ☐ |
| Settings | Log out, then log back in | The feed loads again | ☐ |
| Account | Delete a throwaway account with one photo | The login screen returns, the profiles row is gone, and the account's storage folder is empty | ☐ |

A test that passes on one device and fails on the other usually means realtime or a cache. Check the
troubleshooting table in Step 20 before changing any code.

## Step 21 feature tests

The guide asks for a checklist line for each roadmap feature you build.

### 21.1 Video playback

| Test | Expected | Done |
|---|---|---|
| Open a thread with a video longer than 30 seconds | The still frame (or grey placeholder) and play symbol appear in the grid | ☐ |
| Tap the video cell | Full-screen viewer opens, the player shows a spinner, then the video plays | ☐ |
| Tap the playing video | It pauses; tapping again resumes it | ☐ |
| Turn off Wi-Fi, then open a video not loaded before | The error icon appears, and the rest of the screen still works | ☐ |
| Scroll a feed containing videos | Scrolling stays smooth — videos are not decoded until opened | ☐ |

### 21.2 Deep links and magic links

Run these on a real device (the scheme must be registered with the OS). The Supabase redirect
`threads://login-callback` must be in the dashboard's allow-list first.

| Test | Expected | Done |
|---|---|---|
| Tap "Email me a sign-in link" with a valid email | "Check your email" message appears | ☐ |
| Open the emailed link on the same device | The app opens and is signed in | ☐ |
| Open the emailed link on a different device | The login screen appears, not an error | ☐ |
| Tap the link button with an empty email field | "Enter your email first" message appears | ☐ |

### 21.3 GIF search

Run `supabase/schema.sql`, set a provider key, and deploy first
(`supabase secrets set GIPHY_API_KEY=...` then `supabase functions deploy gif-search`).

| Test | Expected | Done |
|---|---|---|
| Open the composer and tap "Add a GIF" | The picker opens and shows trending GIFs without typing | ☐ |
| Search a common word (e.g. "cat") | A grid of moving GIFs appears | ☐ |
| Pick a GIF, then post | The post shows the animated GIF in the grid with a `GIF` badge | ☐ |
| Tap the GIF in a post | The full-screen viewer shows the animation with a `GIF` badge | ☐ |
| Remove a chosen GIF with its × before posting | It disappears from the media strip and is not posted | ☐ |
| Add GIFs plus photos up to the limit | The "Add …" buttons disappear at 10 items total | ☐ |
| Sign in as a second account and view the post | The second account sees the same animated GIF | ☐ |
| Call the function with no token: `curl -X POST .../functions/v1/gif-search -d '{"query":"cat"}'` | 401 (platform rejects it, and the function would too) | ☐ |
| Call the function while signed out in the app | A readable message appears in the picker, never a blank grid or a crash | ☐ |
| Unset the provider key and search | The picker shows "GIF search is not set up…" (500 from the function) | ☐ |
| Check an old post (made before Step 21.3) with media | Its grid still renders; kinds are inferred from the file extension | ☐ |
| In the SQL Editor, `select media_kinds from public.threads where cardinality(media_urls) > 0;` | New GIF posts show `{gif}`; older posts show `{}` | ☐ |

### 21.4 Link previews

Deploy the function (`supabase functions deploy link-preview`) and run `supabase/schema.sql` first.

| Test | Expected | Done |
|---|---|---|
| Post a thread containing a link to a news article | A card with image, host, title and description appears under the text | ☐ |
| Post a link to a page with no Open Graph tags | Either a title-only card or no card — never an error | ☐ |
| Post a link to `https://localhost` | No card appears (the function rejects the private address) | ☐ |
| Post a link to a page that is not HTML (e.g. a PDF or image) | No card appears (415 from the function) | ☐ |
| Post the same link twice, or reload the feed | The card is served from the cache; the page is not fetched again | ☐ |
| Call the function while signed out, e.g. `curl -X POST .../functions/v1/link-preview -d '{"url":"https://example.com"}'` | The platform rejects the request (JWT verification is on) | ☐ |
| Check `select * from public.link_previews;` in the SQL Editor | Cached rows exist; a signed-in user can read them and cannot write | ☐ |

### 21.5 Communities

| Test | Expected | Done |
|---|---|---|
| Create a community (public, with name/slug/description) | The community appears in the Communities list, the creator is a member, `member_count` is 1 | ☐ |
| Search/filter communities in the list | Name and slug match the query | ☐ |
| Join a public community | `member_count` rises, the button becomes "Joined", and the community feed loads | ☐ |
| Post into a community from the composer | The post appears only in that community's feed, not in For you or Following | ☐ |
| Tap a community post from the community screen | The detail screen opens; replies can be made by members | ☐ |
| Open a public community as a non-member | The header shows the community and a Join button; the feed shows "Join this community to see its threads." | ☐ |
| Create a private community | Only members and the owner see it in the list; a non-member cannot open it | ☐ |
| Remove a member (owner does so) | The removed member loses access at once and the member count drops | ☐ |
| A member leaves a community | They are removed, the feed becomes unavailable to them, and `member_count` decreases | ☐ |
| A community post on an author's profile (as a member) | It is visible to members; RLS prevents non-members from seeing it | ☐ |
