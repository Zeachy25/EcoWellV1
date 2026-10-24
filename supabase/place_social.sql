-- Place likes and comments for the Home "Wellness Score by Location" cards.
-- Run this once in the Supabase SQL editor (Dashboard > SQL > New query).
-- Safe to run again (all statements use IF NOT EXISTS / CREATE OR REPLACE).

-- ---------------------------------------------------------------------------
-- place_likes: one row per (place, user) who hearted the place.
-- Mirrors post_likes.
-- ---------------------------------------------------------------------------
create table if not exists public.place_likes (
  place_id    uuid not null references public.green_spaces (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (place_id, user_id)
);

alter table public.place_likes enable row level security;

drop policy if exists "place_likes select" on public.place_likes;
create policy "place_likes select"
  on public.place_likes for select
  to authenticated
  using (true);

drop policy if exists "place_likes insert own" on public.place_likes;
create policy "place_likes insert own"
  on public.place_likes for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "place_likes delete own" on public.place_likes;
create policy "place_likes delete own"
  on public.place_likes for delete
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- place_comments: comments on a place. Mirrors post_comments.
-- ---------------------------------------------------------------------------
create table if not exists public.place_comments (
  id          uuid not null default gen_random_uuid() primary key,
  place_id    uuid not null references public.green_spaces (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  body        text not null check (char_length(body) between 1 and 500),
  created_at  timestamptz not null default now()
);

create index if not exists place_comments_place_id_idx
  on public.place_comments (place_id, created_at);

alter table public.place_comments enable row level security;

drop policy if exists "place_comments select" on public.place_comments;
create policy "place_comments select"
  on public.place_comments for select
  to authenticated
  using (true);

drop policy if exists "place_comments insert own" on public.place_comments;
create policy "place_comments insert own"
  on public.place_comments for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "place_comments delete own" on public.place_comments;
create policy "place_comments delete own"
  on public.place_comments for delete
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- get_place_social(): like/comment counts + liked_by_me for every place.
-- SECURITY DEFINER so the aggregates work under RLS. Mirrors get_feed's
-- liked_by_me pattern.
-- ---------------------------------------------------------------------------
create or replace function public.get_place_social()
returns table (
  place_id      uuid,
  like_count    bigint,
  comment_count bigint,
  liked_by_me   boolean
)
language sql
security definer
set search_path = public
stable
as $$
  select
    g.id                                              as place_id,
    coalesce(l.likes, 0)                              as like_count,
    coalesce(c.comments, 0)                           as comment_count,
    exists (
      select 1 from public.place_likes pl
      where pl.place_id = g.id and pl.user_id = auth.uid()
    )                                                 as liked_by_me
  from public.green_spaces g
  left join (
    select place_id, count(*) as likes
    from public.place_likes
    group by place_id
  ) l on l.place_id = g.id
  left join (
    select place_id, count(*) as comments
    from public.place_comments
    group by place_id
  ) c on c.place_id = g.id
$$;

grant execute on function public.get_place_social() to authenticated;
