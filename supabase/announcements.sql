-- Public in-app announcements. Publish rows from the Supabase dashboard;
-- this app is read-only and has no admin credentials.

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 160),
  message text not null check (char_length(message) between 1 and 10000),
  link_url text,
  published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  constraint published_announcement_has_date
    check (not published or published_at is not null)
);

create index if not exists announcements_published_at_idx
  on public.announcements (published_at desc)
  where published = true;

alter table public.announcements enable row level security;
grant select on public.announcements to authenticated;

drop policy if exists "announcements read published" on public.announcements;
create policy "announcements read published"
  on public.announcements for select
  to authenticated
  using (published = true and published_at <= now());

-- Enable live delivery to the in-app bell. Re-running this script is safe.
do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'announcements'
  ) then
    alter publication supabase_realtime add table public.announcements;
  end if;
end
$$;
