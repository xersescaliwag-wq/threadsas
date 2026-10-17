-- ============================================================================
-- Threads Clone — Step 2: tables, indexes, business logic, security, storage
-- Run the three parts in order in the Supabase SQL Editor, each part once.
-- Keep this file in the repository as the record of how the database was built.
-- ============================================================================

-- ============================================================================
-- Part A: tables and indexes
-- Each table stores one kind of record. Threads live in a single table. A
-- top-level post has no parent, a reply points to the thread it answers
-- through parent_id, and a quote points to the thread it quotes through
-- quote_id. Counters such as like_count are stored on the row itself, so
-- feeds load quickly without counting rows on every request.
-- ============================================================================

create table if not exists public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  username        text not null unique check (username ~ '^[a-z0-9_.]{3,30}$'),
  display_name    text not null default '' check (char_length(display_name) <= 50),
  bio             text not null default '' check (char_length(bio) <= 150),
  website         text check (website is null or char_length(website) <= 200),
  avatar_url      text,
  is_private      boolean not null default false,
  is_verified     boolean not null default false,
  followers_count integer not null default 0,
  following_count integer not null default 0,
  threads_count   integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table if not exists public.threads (
  id              uuid primary key default gen_random_uuid(),
  author_id       uuid not null references public.profiles (id) on delete cascade,
  content         text not null default '' check (char_length(content) <= 500),
  media_urls      text[] not null default '{}' check (cardinality(media_urls) <= 10),
  parent_id       uuid references public.threads (id) on delete cascade,
  root_id         uuid references public.threads (id) on delete cascade,
  quote_id        uuid references public.threads (id) on delete set null,
  hashtags        text[] not null default '{}',
  mentions        text[] not null default '{}',
  reply_control   text not null default 'everyone'
                  check (reply_control in ('everyone', 'following', 'mentioned')),
  hide_like_count boolean not null default false,
  is_pinned       boolean not null default false,
  expires_at      timestamptz,
  like_count      integer not null default 0,
  reply_count     integer not null default 0,
  repost_count    integer not null default 0,
  quote_count     integer not null default 0,
  edited_at       timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint threads_has_body check (char_length(trim(content)) > 0 or cardinality(media_urls) > 0)
);

create unique index if not exists threads_one_pinned_per_author
  on public.threads (author_id) where is_pinned;
create index if not exists threads_author_idx on public.threads (author_id, created_at desc);
create index if not exists threads_feed_idx on public.threads (created_at desc) where parent_id is null;
create index if not exists threads_root_idx on public.threads (root_id, created_at);
create index if not exists threads_parent_idx on public.threads (parent_id);
create index if not exists threads_quote_idx on public.threads (quote_id);
create index if not exists threads_hashtags_idx on public.threads using gin (hashtags);
create index if not exists threads_mentions_idx on public.threads using gin (mentions);
create index if not exists threads_search_idx on public.threads using gin (to_tsvector('simple', content));

create table if not exists public.likes (
  thread_id  uuid not null references public.threads (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (thread_id, user_id)
);

create table if not exists public.reposts (
  thread_id  uuid not null references public.threads (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (thread_id, user_id)
);

create table if not exists public.follows (
  follower_id  uuid not null references public.profiles (id) on delete cascade,
  following_id uuid not null references public.profiles (id) on delete cascade,
  status       text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at   timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);
create index if not exists follows_following_idx on public.follows (following_id, status);

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.mutes (
  muter_id   uuid not null references public.profiles (id) on delete cascade,
  muted_id   uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (muter_id, muted_id),
  check (muter_id <> muted_id)
);

create table if not exists public.notifications (
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  actor_id     uuid not null references public.profiles (id) on delete cascade,
  type         text not null check (type in ('like', 'reply', 'repost', 'quote', 'mention', 'follow', 'follow_request')),
  thread_id    uuid references public.threads (id) on delete cascade,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);
create index if not exists notifications_recipient_idx on public.notifications (recipient_id, created_at desc);

create table if not exists public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  thread_id   uuid references public.threads (id) on delete cascade,
  profile_id  uuid references public.profiles (id) on delete cascade,
  reason      text not null check (char_length(reason) between 3 and 500),
  status      text not null default 'open' check (status in ('open', 'reviewed', 'dismissed')),
  created_at  timestamptz not null default now(),
  check (thread_id is not null or profile_id is not null)
);

create table if not exists public.polls (
  thread_id  uuid primary key references public.threads (id) on delete cascade,
  ends_at    timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.poll_options (
  id          uuid primary key default gen_random_uuid(),
  thread_id   uuid not null references public.threads (id) on delete cascade,
  label       text not null check (char_length(label) between 1 and 60),
  position    integer not null default 0,
  votes_count integer not null default 0
);
create index if not exists poll_options_thread_idx on public.poll_options (thread_id);

create table if not exists public.poll_votes (
  thread_id  uuid not null references public.polls (thread_id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  option_id  uuid not null references public.poll_options (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (thread_id, user_id)
);

-- ============================================================================
-- Part B: business logic
-- The triggers and functions run automatically whenever data changes, so the
-- app never has to keep counters, notifications or hashtags up to date by
-- hand. Functions marked security definer run with the database owner's
-- rights. Each trigger is dropped before it is created, which keeps the
-- script safe to run again.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- B1: profiles, sign-up and thread rules
-- ----------------------------------------------------------------------------

create or replace function public.touch_profile_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end; $$;

drop trigger if exists trg_profiles_touch on public.profiles;
create trigger trg_profiles_touch
before update on public.profiles
for each row execute function public.touch_profile_updated_at();

-- Creates a profile for every new account. The app passes username and
-- display_name as metadata.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    lower(coalesce(new.raw_user_meta_data ->> 'username',
                   'user_' || substr(replace(new.id::text, '-', ''), 1, 8))),
    coalesce(new.raw_user_meta_data ->> 'display_name', '')
  );
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Returns only true or false, so the app can call it before sign-up.
create or replace function public.is_username_available(candidate text)
returns boolean language sql stable security definer set search_path = public as $$
  select not exists (select 1 from public.profiles p where p.username = lower(candidate));
$$;

-- Before a thread is saved: extract #hashtags and @mentions, link replies to
-- their conversation root, and enforce the reply controls chosen by the
-- parent author.
create or replace function public.threads_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  parent_row public.threads%rowtype;
  my_username text;
begin
  new.hashtags := array(
    select distinct lower(m[2])
    from regexp_matches(new.content, '(^|[^A-Za-z0-9_])#([A-Za-z0-9_]{1,50})', 'g') as m
  );
  new.mentions := array(
    select distinct lower(m[2])
    from regexp_matches(new.content, '(^|[^A-Za-z0-9_.])@([A-Za-z0-9_.]{3,30})', 'g') as m
  );
  if new.parent_id is not null then
    select * into parent_row from public.threads t where t.id = new.parent_id;
    if not found then
      raise exception 'The thread you are replying to no longer exists';
    end if;
    new.root_id := coalesce(parent_row.root_id, parent_row.id);
    if new.author_id <> parent_row.author_id then
      if parent_row.reply_control = 'following' and not exists (
        select 1 from public.follows f
        where f.follower_id = new.author_id
          and f.following_id = parent_row.author_id
          and f.status = 'accepted'
      ) then
        raise exception 'Only accounts followed by the thread author can reply';
      end if;
      if parent_row.reply_control = 'mentioned' then
        select p.username into my_username from public.profiles p where p.id = new.author_id;
        if my_username is null or not (my_username = any (parent_row.mentions)) then
          raise exception 'Only mentioned accounts can reply to this thread';
        end if;
      end if;
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists trg_threads_before_insert on public.threads;
create trigger trg_threads_before_insert
before insert on public.threads
for each row execute function public.threads_before_insert();

-- Re-extract hashtags and mentions when the text changes, and record the
-- edit time.
create or replace function public.threads_before_update()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.content is distinct from old.content then
    new.hashtags := array(
      select distinct lower(m[2])
      from regexp_matches(new.content, '(^|[^A-Za-z0-9_])#([A-Za-z0-9_]{1,50})', 'g') as m
    );
    new.mentions := array(
      select distinct lower(m[2])
      from regexp_matches(new.content, '(^|[^A-Za-z0-9_.])@([A-Za-z0-9_.]{3,30})', 'g') as m
    );
    new.edited_at := now();
  end if;
  new.updated_at := now();
  return new;
end; $$;

drop trigger if exists trg_threads_before_update on public.threads;
create trigger trg_threads_before_update
before update on public.threads
for each row execute function public.threads_before_update();

-- Only one pinned post per author: pinning a post unpins the previous one.
create or replace function public.enforce_single_pin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.is_pinned then
    update public.threads t
       set is_pinned = false
     where t.author_id = new.author_id
       and t.id <> new.id
       and t.is_pinned;
  end if;
  return new;
end; $$;

drop trigger if exists trg_threads_single_pin on public.threads;
create trigger trg_threads_single_pin
before insert or update of is_pinned on public.threads
for each row execute function public.enforce_single_pin();

-- Keeps threads_count on profiles, and reply_count and quote_count on
-- threads.
create or replace function public.maintain_thread_counters()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if new.parent_id is null then
      update public.profiles set threads_count = threads_count + 1 where id = new.author_id;
    else
      update public.threads set reply_count = reply_count + 1 where id = new.parent_id;
    end if;
    if new.quote_id is not null then
      update public.threads set quote_count = quote_count + 1 where id = new.quote_id;
    end if;
    return new;
  end if;
  if old.parent_id is null then
    update public.profiles set threads_count = greatest(threads_count - 1, 0) where id = old.author_id;
  else
    update public.threads set reply_count = greatest(reply_count - 1, 0) where id = old.parent_id;
  end if;
  if old.quote_id is not null then
    update public.threads set quote_count = greatest(quote_count - 1, 0) where id = old.quote_id;
  end if;
  return old;
end; $$;

drop trigger if exists trg_threads_counters on public.threads;
create trigger trg_threads_counters
after insert or delete on public.threads
for each row execute function public.maintain_thread_counters();

-- ----------------------------------------------------------------------------
-- B2: follows, likes, reposts, polls, notifications and blocks
-- ----------------------------------------------------------------------------

-- New follows start as pending for private accounts and as accepted for
-- public ones.
create or replace function public.follows_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.profiles p where p.id = new.following_id and p.is_private) then
    new.status := 'pending';
  else
    new.status := 'accepted';
  end if;
  return new;
end; $$;

drop trigger if exists trg_follows_before_insert on public.follows;
create trigger trg_follows_before_insert
before insert on public.follows
for each row execute function public.follows_before_insert();

-- Follower and following counters. Only accepted follows are counted.
create or replace function public.maintain_follow_counts()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  delta integer := 0;
  v_follower uuid;
  v_followed uuid;
begin
  if tg_op = 'INSERT' then
    if new.status = 'accepted' then delta := 1; end if;
    v_follower := new.follower_id;
    v_followed := new.following_id;
  elsif tg_op = 'UPDATE' then
    if old.status <> 'accepted' and new.status = 'accepted' then delta := 1; end if;
    v_follower := new.follower_id;
    v_followed := new.following_id;
  else
    if old.status = 'accepted' then delta := -1; end if;
    v_follower := old.follower_id;
    v_followed := old.following_id;
  end if;
  if delta <> 0 then
    update public.profiles set following_count = greatest(following_count + delta, 0) where id = v_follower;
    update public.profiles set followers_count = greatest(followers_count + delta, 0) where id = v_followed;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end; $$;

drop trigger if exists trg_follows_counts on public.follows;
create trigger trg_follows_counts
after insert or update or delete on public.follows
for each row execute function public.maintain_follow_counts();

-- Likes and reposts: keep like_count and repost_count in step with the rows.
create or replace function public.maintain_engagement_counts()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  delta integer := 1;
  target uuid;
begin
  if tg_op = 'DELETE' then
    delta := -1;
    target := old.thread_id;
  else
    target := new.thread_id;
  end if;
  if tg_table_name = 'likes' then
    update public.threads set like_count = greatest(like_count + delta, 0) where id = target;
  else
    update public.threads set repost_count = greatest(repost_count + delta, 0) where id = target;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end; $$;

drop trigger if exists trg_likes_counts on public.likes;
create trigger trg_likes_counts
after insert or delete on public.likes
for each row execute function public.maintain_engagement_counts();

drop trigger if exists trg_reposts_counts on public.reposts;
create trigger trg_reposts_counts
after insert or delete on public.reposts
for each row execute function public.maintain_engagement_counts();

-- Poll votes: keep votes_count on each option in step with the votes.
create or replace function public.maintain_poll_votes()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.poll_options set votes_count = votes_count + 1 where id = new.option_id;
    return new;
  end if;
  update public.poll_options set votes_count = greatest(votes_count - 1, 0) where id = old.option_id;
  return old;
end; $$;

drop trigger if exists trg_poll_votes_counts on public.poll_votes;
create trigger trg_poll_votes_counts
after insert or delete on public.poll_votes
for each row execute function public.maintain_poll_votes();

-- The one place notifications are written. Self-notifications and unknown
-- recipients are skipped.
create or replace function public.create_notification(
  p_recipient uuid, p_actor uuid, p_type text, p_thread uuid
) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_recipient is null or p_recipient = p_actor then
    return;
  end if;
  insert into public.notifications (recipient_id, actor_id, type, thread_id)
  values (p_recipient, p_actor, p_type, p_thread);
end; $$;

revoke execute on function public.create_notification(uuid, uuid, text, uuid) from public, anon, authenticated;

-- Likes and reposts notify the author of the thread.
create or replace function public.notify_on_engagement()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  owner_id uuid;
  kind text;
begin
  if tg_table_name = 'likes' then
    kind := 'like';
  else
    kind := 'repost';
  end if;
  select t.author_id into owner_id from public.threads t where t.id = new.thread_id;
  perform public.create_notification(owner_id, new.user_id, kind, new.thread_id);
  return new;
end; $$;

drop trigger if exists trg_likes_notify on public.likes;
create trigger trg_likes_notify
after insert on public.likes
for each row execute function public.notify_on_engagement();

drop trigger if exists trg_reposts_notify on public.reposts;
create trigger trg_reposts_notify
after insert on public.reposts
for each row execute function public.notify_on_engagement();

-- Replies, quotes and mentions each create a notification.
create or replace function public.notify_on_thread_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  target_id uuid;
  mentioned text;
begin
  if new.parent_id is not null then
    select t.author_id into target_id from public.threads t where t.id = new.parent_id;
    perform public.create_notification(target_id, new.author_id, 'reply', new.id);
  end if;
  if new.quote_id is not null then
    select t.author_id into target_id from public.threads t where t.id = new.quote_id;
    perform public.create_notification(target_id, new.author_id, 'quote', new.id);
  end if;
  foreach mentioned in array new.mentions loop
    select p.id into target_id from public.profiles p where p.username = mentioned;
    perform public.create_notification(target_id, new.author_id, 'mention', new.id);
  end loop;
  return new;
end; $$;

drop trigger if exists trg_threads_notify on public.threads;
create trigger trg_threads_notify
after insert on public.threads
for each row execute function public.notify_on_thread_insert();

-- New followers get a follow notification, or a follow request when the
-- account is private.
create or replace function public.notify_on_follow()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.create_notification(
    new.following_id,
    new.follower_id,
    case when new.status = 'pending' then 'follow_request' else 'follow' end,
    null
  );
  return new;
end; $$;

drop trigger if exists trg_follows_notify on public.follows;
create trigger trg_follows_notify
after insert on public.follows
for each row execute function public.notify_on_follow();

-- Blocking removes any follow relationship in both directions.
create or replace function public.remove_follows_on_block()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.follows f
  where (f.follower_id = new.blocker_id and f.following_id = new.blocked_id)
     or (f.follower_id = new.blocked_id and f.following_id = new.blocker_id);
  return new;
end; $$;

drop trigger if exists trg_blocks_remove_follows on public.blocks;
create trigger trg_blocks_remove_follows
after insert on public.blocks
for each row execute function public.remove_follows_on_block();

-- ============================================================================
-- Part C: row level security, storage, realtime and functions
-- RLS is the security layer of the whole project. Once it is switched on, a
-- table returns no rows unless a policy allows them. Column grants add a
-- second layer: they stop a user from changing protected columns such as
-- follower counts or the verified flag, even through their own profile.
-- ============================================================================

alter table public.profiles      enable row level security;
alter table public.threads       enable row level security;
alter table public.likes         enable row level security;
alter table public.reposts       enable row level security;
alter table public.follows       enable row level security;
alter table public.blocks        enable row level security;
alter table public.mutes         enable row level security;
alter table public.notifications enable row level security;
alter table public.reports       enable row level security;
alter table public.polls         enable row level security;
alter table public.poll_options  enable row level security;
alter table public.poll_votes    enable row level security;

-- Profiles: signed-in users can read profiles, except accounts that blocked
-- them. Users can always read their own profile and the accounts they
-- blocked.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
for select to authenticated
using (
  profiles.id = auth.uid()
  or exists (select 1 from public.blocks b where b.blocker_id = auth.uid() and b.blocked_id = profiles.id)
  or not exists (select 1 from public.blocks b where b.blocker_id = profiles.id and b.blocked_id = auth.uid())
);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
for update to authenticated
using (profiles.id = auth.uid())
with check (profiles.id = auth.uid());

-- Users may change only their own editable columns.
revoke update on public.profiles from authenticated;
grant update (username, display_name, bio, website, avatar_url, is_private)
  on public.profiles to authenticated;

-- Threads: visible when the author is public or followed, and no block exists
-- in either direction. Ghost posts disappear once their expiry time has
-- passed.
drop policy if exists threads_select on public.threads;
create policy threads_select on public.threads
for select to authenticated
using (
  (threads.expires_at is null or threads.expires_at > now())
  and not exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = threads.author_id)
       or (b.blocker_id = threads.author_id and b.blocked_id = auth.uid())
  )
  and (
    threads.author_id = auth.uid()
    or exists (select 1 from public.profiles p where p.id = threads.author_id and not p.is_private)
    or exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = threads.author_id
        and f.status = 'accepted'
    )
  )
);

drop policy if exists threads_insert on public.threads;
create policy threads_insert on public.threads
for insert to authenticated
with check (
  threads.author_id = auth.uid()
  and (threads.parent_id is null or exists (select 1 from public.threads p where p.id = threads.parent_id))
  and (threads.quote_id is null or exists (select 1 from public.threads q where q.id = threads.quote_id))
);

drop policy if exists threads_update_own on public.threads;
create policy threads_update_own on public.threads
for update to authenticated
using (threads.author_id = auth.uid())
with check (threads.author_id = auth.uid());

drop policy if exists threads_delete_own on public.threads;
create policy threads_delete_own on public.threads
for delete to authenticated
using (threads.author_id = auth.uid());

-- Authors may edit only these columns. Counters and derived fields are
-- server-only.
revoke update on public.threads from authenticated;
grant update (content, media_urls, reply_control, hide_like_count, is_pinned)
  on public.threads to authenticated;

-- Likes: you manage your own likes. The author of a thread can see who liked
-- it.
drop policy if exists likes_select on public.likes;
create policy likes_select on public.likes
for select to authenticated
using (
  likes.user_id = auth.uid()
  or exists (select 1 from public.threads t where t.id = likes.thread_id and t.author_id = auth.uid())
);

drop policy if exists likes_insert on public.likes;
create policy likes_insert on public.likes
for insert to authenticated
with check (
  likes.user_id = auth.uid()
  and exists (select 1 from public.threads t where t.id = likes.thread_id)
);

drop policy if exists likes_delete on public.likes;
create policy likes_delete on public.likes
for delete to authenticated
using (likes.user_id = auth.uid());

-- Reposts: visible on every thread you can see. You create and remove only
-- your own.
drop policy if exists reposts_select on public.reposts;
create policy reposts_select on public.reposts
for select to authenticated
using (exists (select 1 from public.threads t where t.id = reposts.thread_id));

drop policy if exists reposts_insert on public.reposts;
create policy reposts_insert on public.reposts
for insert to authenticated
with check (
  reposts.user_id = auth.uid()
  and exists (select 1 from public.threads t where t.id = reposts.thread_id)
);

drop policy if exists reposts_delete on public.reposts;
create policy reposts_delete on public.reposts
for delete to authenticated
using (reposts.user_id = auth.uid());

-- Follows: accepted follows are public. Pending requests are visible only to
-- the two people involved.
drop policy if exists follows_select on public.follows;
create policy follows_select on public.follows
for select to authenticated
using (
  follows.status = 'accepted'
  or follows.follower_id = auth.uid()
  or follows.following_id = auth.uid()
);

drop policy if exists follows_insert on public.follows;
create policy follows_insert on public.follows
for insert to authenticated
with check (
  follows.follower_id = auth.uid()
  and exists (select 1 from public.profiles p where p.id = follows.following_id)
  and not exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = follows.following_id)
       or (b.blocker_id = follows.following_id and b.blocked_id = auth.uid())
  )
);

drop policy if exists follows_update on public.follows;
create policy follows_update on public.follows
for update to authenticated
using (follows.following_id = auth.uid())
with check (follows.following_id = auth.uid());

drop policy if exists follows_delete on public.follows;
create policy follows_delete on public.follows
for delete to authenticated
using (follows.follower_id = auth.uid() or follows.following_id = auth.uid());

-- The target of a follow request may change only its status, which is how it
-- accepts.
revoke update on public.follows from authenticated;
grant update (status) on public.follows to authenticated;

-- Blocks and mutes are private to the person who created them.
drop policy if exists blocks_owner on public.blocks;
create policy blocks_owner on public.blocks
for all to authenticated
using (blocks.blocker_id = auth.uid())
with check (blocks.blocker_id = auth.uid());

drop policy if exists mutes_owner on public.mutes;
create policy mutes_owner on public.mutes
for all to authenticated
using (mutes.muter_id = auth.uid())
with check (mutes.muter_id = auth.uid());

-- Notifications: you can read, mark as read and delete your own. Only
-- triggers insert them.
drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications
for select to authenticated
using (notifications.recipient_id = auth.uid());

drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications
for update to authenticated
using (notifications.recipient_id = auth.uid())
with check (notifications.recipient_id = auth.uid());

drop policy if exists notifications_delete on public.notifications;
create policy notifications_delete on public.notifications
for delete to authenticated
using (notifications.recipient_id = auth.uid());

revoke update on public.notifications from authenticated;
grant update (is_read) on public.notifications to authenticated;

-- Reports: you can file a report and see the reports you filed.
drop policy if exists reports_insert on public.reports;
create policy reports_insert on public.reports
for insert to authenticated
with check (reports.reporter_id = auth.uid());

drop policy if exists reports_select on public.reports;
create policy reports_select on public.reports
for select to authenticated
using (reports.reporter_id = auth.uid());

-- Polls: anyone who can see a thread can see its poll. Only the author
-- creates the poll.
drop policy if exists polls_select on public.polls;
create policy polls_select on public.polls
for select to authenticated
using (exists (select 1 from public.threads t where t.id = polls.thread_id));

drop policy if exists polls_insert on public.polls;
create policy polls_insert on public.polls
for insert to authenticated
with check (exists (select 1 from public.threads t where t.id = polls.thread_id and t.author_id = auth.uid()));

drop policy if exists poll_options_select on public.poll_options;
create policy poll_options_select on public.poll_options
for select to authenticated
using (exists (select 1 from public.threads t where t.id = poll_options.thread_id));

drop policy if exists poll_options_insert on public.poll_options;
create policy poll_options_insert on public.poll_options
for insert to authenticated
with check (exists (select 1 from public.threads t where t.id = poll_options.thread_id and t.author_id = auth.uid()));

-- Votes: you see only your own vote. You can vote once, while the poll is
-- open and the thread is visible.
drop policy if exists poll_votes_select on public.poll_votes;
create policy poll_votes_select on public.poll_votes
for select to authenticated
using (poll_votes.user_id = auth.uid());

drop policy if exists poll_votes_insert on public.poll_votes;
create policy poll_votes_insert on public.poll_votes
for insert to authenticated
with check (
  poll_votes.user_id = auth.uid()
  and exists (select 1 from public.threads t where t.id = poll_votes.thread_id)
  and exists (
    select 1 from public.polls p
    where p.thread_id = poll_votes.thread_id and p.ends_at > now()
  )
  and exists (
    select 1 from public.poll_options o
    where o.id = poll_votes.option_id and o.thread_id = poll_votes.thread_id
  )
);

-- Storage: avatars and thread media are public to read. Each user writes
-- only inside their own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('thread-media', 'thread-media', true, 52428800,
   array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/quicktime'])
on conflict (id) do nothing;

drop policy if exists media_read on storage.objects;
create policy media_read on storage.objects
for select to public
using (bucket_id in ('avatars', 'thread-media'));

drop policy if exists media_insert_own_folder on storage.objects;
create policy media_insert_own_folder on storage.objects
for insert to authenticated
with check (
  bucket_id in ('avatars', 'thread-media')
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists media_update_own_folder on storage.objects;
create policy media_update_own_folder on storage.objects
for update to authenticated
using (bucket_id in ('avatars', 'thread-media') and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists media_delete_own_folder on storage.objects;
create policy media_delete_own_folder on storage.objects
for delete to authenticated
using (bucket_id in ('avatars', 'thread-media') and (storage.foldername(name))[1] = auth.uid()::text);

-- Realtime: push row changes for these tables to subscribed apps. Run this
-- once. If it errors because a table is already in the publication, that is
-- fine.
alter publication supabase_realtime add table public.threads;
alter publication supabase_realtime add table public.likes;
alter publication supabase_realtime add table public.notifications;

-- Search: full-text search over thread text. It runs as the caller, so RLS
-- still applies.
create or replace function public.search_threads(q text)
returns setof public.threads
language sql stable security invoker set search_path = public as $$
  select t.*
  from public.threads t
  where to_tsvector('simple', t.content) @@ websearch_to_tsquery('simple', q)
  order by t.created_at desc
  limit 50;
$$;

-- Step 15: topic suggestions. Runs as the caller, so RLS still applies. It
-- counts only threads the caller is allowed to see. An empty query returns the
-- most used topics, which the search screen shows as Popular topics.
create or replace function public.search_topics(q text)
returns table (tag text, uses bigint)
language sql stable security invoker set search_path = public as $$
  select h.tag as tag, count(*) as uses
  from public.threads t
  cross join lateral unnest(t.hashtags) as h(tag)
  where starts_with(h.tag, lower(regexp_replace(q, '[^A-Za-z0-9_]', '', 'g')))
  group by h.tag
  order by uses desc, h.tag
  limit 20;
$$;

-- Deletes the signed-in user's account. Their profile and content are
-- removed by cascade.
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from auth.users where id = auth.uid();
end; $$;
revoke execute on function public.delete_my_account() from public, anon;

-- Optional: delete expired ghost posts every 30 minutes. Enable pg_cron
-- first under Database, then Extensions.
-- select cron.schedule('delete-expired-ghost-posts', '*/30 * * * *',
--   $$delete from public.threads where expires_at < now()$$);

-- Step 19 REPLACES the one-line job above. The line deletes the rows but
-- leaves the photos and videos in the 'thread-media' bucket forever, so the
-- Edge Function supabase/functions/cleanup-expired deletes the files first and
-- then the rows. Do NOT run both jobs: two cleanups would race each other.
--
-- Enable pg_cron and pg_net under Database > Extensions, deploy the function
-- (see TASKS.md Step 19), then run this once in the SQL Editor with your own
-- secret in place of YOUR_SECRET (the same value you set with
-- `supabase secrets set CRON_SECRET=...`):
--
-- select cron.schedule(
--   'cleanup-expired-ghosts',
--   '*/30 * * * *',
--   $$
--   select net.http_post(
--     url := 'https://dfccorjkvgvigzrpbiny.supabase.co/functions/v1/cleanup-expired',
--     headers := jsonb_build_object('x-cron-secret', 'YOUR_SECRET')
--   );
--   $$
-- );
--
-- Check the job exists:
-- select jobid, jobname, schedule, active from cron.job;
--
-- Check the function's answer (200 = ran, 403 = secret mismatch):
-- select status_code, content, created from net._http_response
-- order by created desc limit 5;

-- ============================================================================
-- Step 21.4: link preview cache
-- The link-preview Edge Function fetches a page once, reads its Open Graph
-- tags and stores them here. Signed-in users may read the cache; there is no
-- insert, update or delete policy, so only the function (which runs with the
-- service role and bypasses RLS) ever writes.
-- ============================================================================

create table if not exists public.link_previews (
  url         text primary key,
  title       text,
  description text,
  image_url   text,
  fetched_at  timestamptz not null default now()
);

alter table public.link_previews enable row level security;

drop policy if exists link_previews_select on public.link_previews;
create policy link_previews_select on public.link_previews
for select to authenticated
using (true);

-- ============================================================================
-- Step 21.3: GIF posts
-- media_kinds runs alongside media_urls and says which items are images, videos
-- or GIFs, so the grid can draw the right badge. It is added here rather than
-- in the Step 2 table so that Step 2 stays exactly as the guide prints it.
-- ============================================================================

alter table public.threads
  add column if not exists media_kinds text[] not null default '{}';

alter table public.threads drop constraint if exists threads_media_kinds_check;
alter table public.threads add constraint threads_media_kinds_check
  check (
    cardinality(media_kinds) <= 10
    and media_kinds <@ array['image', 'video', 'gif']::text[]
  );

-- media_kinds is parallel to media_urls, so an author may update it the same
-- way. The Step 2 update grant revokes the table and re-grants a column list,
-- so the new column is granted here rather than by editing that printed line.
grant update (media_kinds) on public.threads to authenticated;

-- ============================================================================
-- Step 21.5: communities
-- A community is a group people join, and its posts appear in a feed of their
-- own. Membership decides what can be read and written, so a policy checks
-- membership before it allows a read or a write.
-- ============================================================================

create table if not exists public.communities (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null references public.profiles (id) on delete cascade,
  slug         text not null unique check (slug ~ '^[a-z0-9_]{3,30}$'),
  name         text not null check (char_length(name) between 3 and 60),
  description  text not null default '' check (char_length(description) <= 300),
  is_private   boolean not null default false,
  member_count integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.community_members (
  community_id uuid not null references public.communities (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  role         text not null default 'member' check (role in ('owner', 'moderator', 'member')),
  created_at   timestamptz not null default now(),
  primary key (community_id, user_id)
);

create index if not exists community_members_user_idx
  on public.community_members (user_id);

-- A community post is a normal thread that carries a community id. Deleting a
-- community deletes its posts too: a plain set-null would turn posts that were
-- private to members into posts everyone could read.
alter table public.threads
  add column if not exists community_id uuid references public.communities (id) on delete cascade;

create index if not exists threads_community_idx
  on public.threads (community_id, created_at desc) where community_id is not null;

-- Membership is checked from inside the policies. A plain subquery would run
-- the policy of community_members again and recurse, so this runs as the owner
-- of the function and skips RLS.
create or replace function public.is_community_member(p_community uuid, p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.community_members
    where community_id = p_community and user_id = p_user
  );
$$;

revoke execute on function public.is_community_member(uuid, uuid) from public, anon;
grant execute on function public.is_community_member(uuid, uuid) to authenticated;

-- Creating a community also makes the creator its owner member, in one step.
-- This runs with definer rights, so it works before any membership policy could
-- allow the insert.
create or replace function public.add_community_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.community_members (community_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists communities_add_owner on public.communities;
create trigger communities_add_owner
  after insert on public.communities
  for each row execute function public.add_community_owner();

-- member_count follows the membership rows.
create or replace function public.sync_community_member_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.communities
      set member_count = member_count + 1
      where id = new.community_id;
  elsif tg_op = 'DELETE' then
    update public.communities
      set member_count = greatest(member_count - 1, 0)
      where id = old.community_id;
  end if;
  return null;
end;
$$;

drop trigger if exists community_members_count on public.community_members;
create trigger community_members_count
  after insert or delete on public.community_members
  for each row execute function public.sync_community_member_count();

alter table public.communities      enable row level security;
alter table public.community_members enable row level security;

-- A public community is visible to everyone signed in; a private one only to
-- its members and its owner.
drop policy if exists communities_select on public.communities;
create policy communities_select on public.communities
for select to authenticated
using (
  not is_private
  or owner_id = auth.uid()
  or public.is_community_member(id, auth.uid())
);

drop policy if exists communities_insert on public.communities;
create policy communities_insert on public.communities
for insert to authenticated
with check (owner_id = auth.uid());

drop policy if exists communities_update_own on public.communities;
create policy communities_update_own on public.communities
for update to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists communities_delete_own on public.communities;
create policy communities_delete_own on public.communities
for delete to authenticated
using (owner_id = auth.uid());

-- Membership rows are visible to members of that community and to anyone who
-- can see a public community.
drop policy if exists community_members_select on public.community_members;
create policy community_members_select on public.community_members
for select to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.communities c
    where c.id = community_members.community_id
      and (not c.is_private or c.owner_id = auth.uid())
  )
);

-- Join as yourself, and only into a community you are allowed to see.
drop policy if exists community_members_insert on public.community_members;
create policy community_members_insert on public.community_members
for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.communities c
    where c.id = community_members.community_id
      and (not c.is_private or public.is_community_member(c.id, auth.uid()) or c.owner_id = auth.uid())
  )
);

-- Leave, or be removed by the owner.
drop policy if exists community_members_delete on public.community_members;
create policy community_members_delete on public.community_members
for delete to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.communities c
    where c.id = community_members.community_id and c.owner_id = auth.uid()
  )
);

-- Only the role may change, and only the owner may change it.
revoke update on public.community_members from authenticated;
grant update (role) on public.community_members to authenticated;
drop policy if exists community_members_update_role on public.community_members;
create policy community_members_update_role on public.community_members
for update to authenticated
using (
  exists (
    select 1 from public.communities c
    where c.id = community_members.community_id and c.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.communities c
    where c.id = community_members.community_id and c.owner_id = auth.uid()
  )
);

-- Community posts are readable only by members of that community (and the
-- author). This is a restrictive policy, so it is ANDed with the Step 2
-- threads_select policy rather than replacing it, which leaves that printed
-- policy exactly as the guide has it.
drop policy if exists threads_community_read on public.threads;
create policy threads_community_read on public.threads
as restrictive
for select to authenticated
using (
  community_id is null
  or author_id = auth.uid()
  or public.is_community_member(community_id, auth.uid())
);

-- You may post into a community only if you belong to it.
drop policy if exists threads_community_insert on public.threads;
create policy threads_community_insert on public.threads
as restrictive
for insert to authenticated
with check (
  community_id is null
  or public.is_community_member(community_id, auth.uid())
);

-- Check: every table listed here should show true.
select tablename, rowsecurity from pg_tables where schemaname = 'public' order by tablename;
