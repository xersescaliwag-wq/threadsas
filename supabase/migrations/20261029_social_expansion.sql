-- Additive social expansion. Run after supabase/schema.sql.
-- No existing tables, columns, policies or data are removed.

create table if not exists public.user_interests (
  user_id uuid not null references public.profiles(id) on delete cascade,
  topic text not null check (char_length(topic) between 1 and 80),
  weight numeric not null default 1 check (weight >= 0),
  created_at timestamptz not null default now(),
  primary key (user_id, topic)
);

create table if not exists public.muted_topics (
  user_id uuid not null references public.profiles(id) on delete cascade,
  topic text not null check (char_length(topic) between 1 and 80),
  created_at timestamptz not null default now(),
  primary key (user_id, topic)
);

create table if not exists public.custom_feeds (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 50),
  description text not null default '' check (char_length(description) <= 160),
  is_private boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.custom_feed_members (
  feed_id uuid not null references public.custom_feeds(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (feed_id, profile_id)
);

create table if not exists public.post_drafts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  content text not null default '' check (char_length(content) <= 500),
  media_urls text[] not null default '{}',
  media_kinds text[] not null default '{}',
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.scheduled_posts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  content text not null default '' check (char_length(content) <= 500),
  media_urls text[] not null default '{}',
  media_kinds text[] not null default '{}',
  metadata jsonb not null default '{}'::jsonb,
  scheduled_for timestamptz not null,
  published_thread_id uuid references public.threads(id) on delete set null,
  status text not null default 'scheduled' check (status in ('scheduled', 'publishing', 'published', 'failed', 'cancelled')),
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.post_impressions (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.threads(id) on delete cascade,
  viewer_id uuid references public.profiles(id) on delete set null,
  session_id text,
  created_at timestamptz not null default now()
);

create table if not exists public.profile_impressions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  viewer_id uuid references public.profiles(id) on delete set null,
  session_id text,
  created_at timestamptz not null default now()
);

create table if not exists public.message_requests (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  conversation_id uuid references public.conversations(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (recipient_id, sender_id)
);

create table if not exists public.community_topics (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 50),
  created_at timestamptz not null default now(),
  unique (community_id, name)
);

create table if not exists public.community_chat_channels (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 50),
  created_at timestamptz not null default now(),
  unique (community_id, name)
);

create table if not exists public.community_messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.community_chat_channels(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  media_urls text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists scheduled_posts_due_idx on public.scheduled_posts(status, scheduled_for);
create index if not exists post_impressions_thread_idx on public.post_impressions(thread_id, created_at desc);
create index if not exists profile_impressions_profile_idx on public.profile_impressions(profile_id, created_at desc);
create index if not exists message_requests_recipient_idx on public.message_requests(recipient_id, status, created_at desc);
create index if not exists community_messages_channel_idx on public.community_messages(channel_id, created_at desc);

alter table public.user_interests enable row level security;
alter table public.muted_topics enable row level security;
alter table public.custom_feeds enable row level security;
alter table public.custom_feed_members enable row level security;
alter table public.post_drafts enable row level security;
alter table public.scheduled_posts enable row level security;
alter table public.post_impressions enable row level security;
alter table public.profile_impressions enable row level security;
alter table public.message_requests enable row level security;
alter table public.community_topics enable row level security;
alter table public.community_chat_channels enable row level security;
alter table public.community_messages enable row level security;

drop policy if exists user_interests_owner on public.user_interests;
create policy user_interests_owner on public.user_interests for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists muted_topics_owner on public.muted_topics;
create policy muted_topics_owner on public.muted_topics for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists custom_feeds_owner on public.custom_feeds;
create policy custom_feeds_owner on public.custom_feeds for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists custom_feed_members_owner on public.custom_feed_members;
create policy custom_feed_members_owner on public.custom_feed_members for all using (exists (select 1 from public.custom_feeds f where f.id = feed_id and f.owner_id = auth.uid())) with check (exists (select 1 from public.custom_feeds f where f.id = feed_id and f.owner_id = auth.uid()));
drop policy if exists drafts_owner on public.post_drafts;
create policy drafts_owner on public.post_drafts for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists schedules_owner on public.scheduled_posts;
create policy schedules_owner on public.scheduled_posts for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists impression_insert on public.post_impressions;
create policy impression_insert on public.post_impressions for insert with check (viewer_id = auth.uid() or viewer_id is null);
drop policy if exists profile_impression_insert on public.profile_impressions;
create policy profile_impression_insert on public.profile_impressions for insert with check (viewer_id = auth.uid() or viewer_id is null);
drop policy if exists message_requests_participants on public.message_requests;
create policy message_requests_participants on public.message_requests for all using (recipient_id = auth.uid() or sender_id = auth.uid()) with check (recipient_id = auth.uid() or sender_id = auth.uid());
drop policy if exists community_topics_member on public.community_topics;
create policy community_topics_member on public.community_topics for all using (public.is_community_member(community_id, auth.uid())) with check (public.is_community_member(community_id, auth.uid()));
drop policy if exists community_channels_member on public.community_chat_channels;
create policy community_channels_member on public.community_chat_channels for all using (public.is_community_member(community_id, auth.uid())) with check (public.is_community_member(community_id, auth.uid()));
drop policy if exists community_messages_member on public.community_messages;
create policy community_messages_member on public.community_messages for all using (exists (select 1 from public.community_chat_channels c where c.id = channel_id and public.is_community_member(c.community_id, auth.uid()))) with check (exists (select 1 from public.community_chat_channels c where c.id = channel_id and public.is_community_member(c.community_id, auth.uid())) and author_id = auth.uid());

alter publication supabase_realtime add table public.message_requests;
alter publication supabase_realtime add table public.community_messages;

-- After deploying publish-scheduled, configure the project scheduler with:
-- select cron.schedule('publish-scheduled-posts', '* * * * *',
--   $$select net.http_post(
--     url := 'https://<project-ref>.supabase.co/functions/v1/publish-scheduled',
--     headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', '<CRON_SECRET>'),
--     body := '{}'::jsonb
--   )$$);
