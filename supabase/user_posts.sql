-- Following list + a single user's posts for the profile screen.
-- Run this once in the Supabase SQL editor (Dashboard > SQL > New query).
-- Safe to run again (CREATE OR REPLACE).
--
-- get_user_posts() mirrors get_feed() from Migration 008 exactly, filtered
-- to one author, so the app can parse both with the same code.

-- ---------------------------------------------------------------------------
-- get_following_profiles(): everyone the signed-in user follows, with the
-- display name and avatar (public_profiles: name + avatar only).
-- ---------------------------------------------------------------------------
create or replace function public.get_following_profiles()
returns table (user_id uuid, full_name text, avatar_url text)
language sql
stable
set search_path = public
as $$
  select f.following_id, pr.full_name, pr.avatar_url
    from public.follows f
    join public.public_profiles pr on pr.id = f.following_id
   where f.follower_id = auth.uid()
   order by pr.full_name;
$$;

grant execute on function public.get_following_profiles() to authenticated;

-- ---------------------------------------------------------------------------
-- get_user_posts(p_user_id): one user's posts, newest first, in the exact
-- JSON shape get_feed() returns (FeedPost.fromJson in the app).
-- ---------------------------------------------------------------------------
create or replace function public.get_user_posts(p_user_id uuid)
returns jsonb
language sql
stable
set search_path = public
as $$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id',               p.id,
      'caption',          p.caption,
      'created_at',       p.created_at,
      'author', jsonb_build_object('id', pr.id, 'name', pr.full_name, 'avatar_url', pr.avatar_url),
      'place_id',         p.place_id,
      'place_name',       g.name,
      'place_address',    g.address,
      'place_score',      gs.quiet_score_avg,
      'photos', coalesce(
        (select jsonb_agg(m.storage_path order by m.sort_order)
         from public.post_media m where m.post_id = p.id), '[]'::jsonb),
      'like_count',    (select count(*) from public.post_likes l where l.post_id = p.id),
      'comment_count', (select count(*) from public.post_comments c where c.post_id = p.id),
      'liked_by_me',   exists (select 1 from public.post_likes l
                               where l.post_id = p.id and l.user_id = auth.uid()),
      'likers', coalesce(
        (select jsonb_agg(jsonb_build_object('name', lp.full_name, 'avatar_url', lp.avatar_url))
         from (select l.user_id from public.post_likes l
               where l.post_id = p.id order by l.created_at desc limit 3) x
         join public.public_profiles lp on lp.id = x.user_id), '[]'::jsonb),
      'visit_minutes',    p.visit_minutes,
      'stress_reduction', p.stress_reduction
    ) order by p.created_at desc
  ), '[]'::jsonb)
  from public.posts p
  join public.public_profiles pr on pr.id = p.user_id
  left join public.green_spaces g on g.id = p.place_id
  left join public.green_spaces_with_stats gs on gs.id = p.place_id
  where p.user_id = p_user_id
  limit 50;
$$;

grant execute on function public.get_user_posts(uuid) to authenticated;
