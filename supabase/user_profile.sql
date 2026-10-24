-- Facebook-style profiles: bio, cover photo, avatar uploads, profile header.
-- Run this once in the Supabase SQL editor (Dashboard > SQL > New query).
-- Safe to run again (IF NOT EXISTS / CREATE OR REPLACE / DROP ... IF EXISTS).

-- ---------------------------------------------------------------------------
-- 1) New columns on profiles (bio text + cover photo + joined date).
--    Existing rows get created_at = now() automatically.
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists cover_url text;
alter table public.profiles add column if not exists created_at timestamptz
  default now();

-- ---------------------------------------------------------------------------
-- 2) Public storage buckets for the profile and cover photos.
--    Photos are read through the public URL; writes are limited to a folder
--    named after the signed-in user (<uid>/...).
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('covers', 'covers', true)
on conflict (id) do nothing;

drop policy if exists "profile photos read" on storage.objects;
create policy "profile photos read" on storage.objects
for select to authenticated
using (bucket_id in ('avatars', 'covers'));

drop policy if exists "profile photos owner insert" on storage.objects;
create policy "profile photos owner insert" on storage.objects
for insert to authenticated
with check (
  bucket_id in ('avatars', 'covers')
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "profile photos owner update" on storage.objects;
create policy "profile photos owner update" on storage.objects
for update to authenticated
using (
  bucket_id in ('avatars', 'covers')
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "profile photos owner delete" on storage.objects;
create policy "profile photos owner delete" on storage.objects
for delete to authenticated
using (
  bucket_id in ('avatars', 'covers')
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- ---------------------------------------------------------------------------
-- 3) get_profile(p_user_id): the public header of any user's profile.
--    Returns only what everyone may see: name, photos, bio, joined date,
--    follow/post counts and whether the viewer follows this person.
--    Never exposes birthdate, consent or any wellness scores.
--    Returns NULL when the id does not exist.
-- ---------------------------------------------------------------------------
create or replace function public.get_profile(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_user_id is null
      or not exists (select 1 from public.profiles pr where pr.id = p_user_id)
    then null::jsonb
    else (
      select jsonb_build_object(
        'id',              pr.id,
        'full_name',       pr.full_name,
        'avatar_url',      pr.avatar_url,
        'cover_url',       pr.cover_url,
        'bio',             pr.bio,
        'joined_at',       pr.created_at,
        'follower_count',  (select count(*) from public.follows f
                             where f.following_id = pr.id),
        'following_count', (select count(*) from public.follows f
                             where f.follower_id = pr.id),
        'post_count',      (select count(*) from public.posts po
                             where po.user_id = pr.id),
        'followed_by_me',  exists (select 1 from public.follows f
                                    where f.follower_id = auth.uid()
                                      and f.following_id = pr.id)
      )
      from public.profiles pr
      where pr.id = p_user_id
    )
  end;
$$;

grant execute on function public.get_profile(uuid) to authenticated;
