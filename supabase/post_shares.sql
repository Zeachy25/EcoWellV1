alter table public.posts
  add column if not exists shared_post_id uuid,
  add column if not exists shared_place_id uuid;

alter table public.posts
  drop constraint if exists posts_one_share_target;

alter table public.posts
  add constraint posts_one_share_target
  check (not (shared_post_id is not null and shared_place_id is not null));

create index if not exists posts_shared_post_id_idx
  on public.posts (shared_post_id);

create index if not exists posts_shared_place_id_idx
  on public.posts (shared_place_id);

create or replace function public.feed_post_json(
  p_id uuid,
  p_include_shared boolean default true
)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object(
    'id',               p.id,
    'caption',          p.caption,
    'created_at',       p.created_at,
    'author', jsonb_build_object(
      'id', pr.id,
      'name', pr.full_name,
      'avatar_url', pr.avatar_url
    ),
    'place_id',         p.place_id,
    'place_name',       g.name,
    'place_address',    g.address,
    'place_score',      gs.quiet_score_avg,
    'photos', coalesce(
      (select jsonb_agg(m.storage_path order by m.sort_order)
       from public.post_media m where m.post_id = p.id), '[]'::jsonb),
    'like_count',    (select count(*) from public.post_likes l where l.post_id = p.id),
    'comment_count', (select count(*) from public.post_comments c where c.post_id = p.id),
    'liked_by_me',   exists (
      select 1 from public.post_likes l
      where l.post_id = p.id and l.user_id = auth.uid()
    ),
    'likers', coalesce(
      (select jsonb_agg(jsonb_build_object('name', lp.full_name, 'avatar_url', lp.avatar_url))
       from (
         select l.user_id
         from public.post_likes l
         where l.post_id = p.id
         order by l.created_at desc
         limit 3
       ) x
       join public.public_profiles lp on lp.id = x.user_id), '[]'::jsonb),
    'visit_minutes',    p.visit_minutes,
    'stress_reduction', p.stress_reduction,
    'shared_post_id',   p.shared_post_id,
    'shared_place_id',  p.shared_place_id,
    'shared_post', case
      when p_include_shared and p.shared_post_id is not null
        then public.feed_post_json(p.shared_post_id, false)
      else null
    end,
    'shared_place', case
      when p_include_shared and p.shared_place_id is not null
        then (
          select jsonb_build_object(
            'id',                 sg.id,
            'name',               sg.name,
            'description',        sg.description,
            'category',           sg.category,
            'address',            sg.address,
            'photo_url',          sg.photo_url,
            'lat',                st_y(sg.center::geometry),
            'lng',                st_x(sg.center::geometry),
            'boundary_geojson',   st_asgeojson(sg.boundary::geometry)::jsonb,
            'quiet_score_avg',    sgs.quiet_score_avg,
            'quiet_rating_count', sgs.quiet_rating_count
          )
          from public.green_spaces sg
          left join public.green_spaces_with_stats sgs on sgs.id = sg.id
          where sg.id = p.shared_place_id
        )
      else null
    end
  )
  from public.posts p
  join public.public_profiles pr on pr.id = p.user_id
  left join public.green_spaces g on g.id = p.place_id
  left join public.green_spaces_with_stats gs on gs.id = p.place_id
  where p.id = p_id;
$$;

create or replace function public.get_feed(
  p_limit integer default 20,
  p_before timestamptz default null,
  p_following_only boolean default false
)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    jsonb_agg(public.feed_post_json(p.id) order by p.created_at desc),
    '[]'::jsonb
  )
  from (
    select p.id, p.created_at
    from public.posts p
    where (p_before is null or p.created_at < p_before)
      and (
        not coalesce(p_following_only, false)
        or p.user_id = auth.uid()
        or exists (
          select 1
          from public.follows f
          where f.follower_id = auth.uid()
            and f.following_id = p.user_id
        )
      )
    order by p.created_at desc
    limit greatest(coalesce(p_limit, 20), 1)
  ) p;
$$;

create or replace function public.get_user_posts(p_user_id uuid)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    jsonb_agg(public.feed_post_json(p.id) order by p.created_at desc),
    '[]'::jsonb
  )
  from (
    select id, created_at
    from public.posts
    where user_id = p_user_id
    order by created_at desc
    limit 50
  ) p;
$$;

create or replace function public.share_post_to_feed(
  p_post_id uuid,
  p_caption text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_post public.posts%rowtype;
  v_id uuid := gen_random_uuid();
begin
  if v_user is null then
    raise exception 'Not signed in';
  end if;

  select * into v_post from public.posts where id = p_post_id;
  if not found then
    raise exception 'Post not found';
  end if;

  if v_post.shared_post_id is not null or v_post.shared_place_id is not null then
    raise exception 'Shared posts cannot be shared again';
  end if;

  insert into public.posts (
    id, user_id, place_id, caption, shared_post_id, created_at
  ) values (
    v_id,
    v_user,
    v_post.place_id,
    left(coalesce(p_caption, ''), 500),
    p_post_id,
    now()
  );

  return v_id;
end;
$$;

create or replace function public.share_place_to_feed(
  p_place_id uuid,
  p_caption text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_id uuid := gen_random_uuid();
begin
  if v_user is null then
    raise exception 'Not signed in';
  end if;

  if not exists (select 1 from public.green_spaces where id = p_place_id) then
    raise exception 'Place not found';
  end if;

  insert into public.posts (
    id, user_id, place_id, caption, shared_place_id, created_at
  ) values (
    v_id,
    v_user,
    p_place_id,
    left(coalesce(p_caption, ''), 500),
    p_place_id,
    now()
  );

  return v_id;
end;
$$;

revoke all on function public.feed_post_json(uuid, boolean)
  from public, anon, authenticated;

grant execute on function public.get_feed(integer, timestamptz, boolean)
  to authenticated;
grant execute on function public.get_user_posts(uuid)
  to authenticated;
grant execute on function public.share_post_to_feed(uuid, text)
  to authenticated;
grant execute on function public.share_place_to_feed(uuid, text)
  to authenticated;

notify pgrst, 'reload schema';
