-- Quick Run: GPS walks and runs recorded in the app (the "+" button).
-- Run this once in the Supabase SQL editor (Dashboard > SQL > New query).
-- Safe to run again (all statements use IF NOT EXISTS / OR REPLACE).

-- ---------------------------------------------------------------------------
-- runs: one row per finished walk/run. The phone generates the UUID and
-- sends it with the insert, so retrying a failed upload never creates a
-- duplicate row. `path` holds the recorded polyline as
-- [[lat, lng, epochSeconds], ...].
-- ---------------------------------------------------------------------------
create table if not exists public.runs (
  id                 uuid not null default gen_random_uuid() primary key,
  user_id            uuid not null references auth.users (id) on delete cascade,
  activity_type      text not null check (activity_type in ('walk', 'run')),
  started_at         timestamptz not null,
  ended_at           timestamptz not null,
  distance_m         double precision not null default 0,
  duration_s         integer not null default 0,
  avg_pace_s_per_km  integer,
  path               jsonb not null default '[]'::jsonb,
  created_at         timestamptz not null default now()
);

create index if not exists runs_user_id_started_at_idx
  on public.runs (user_id, started_at desc);

alter table public.runs enable row level security;

drop policy if exists "runs select own" on public.runs;
create policy "runs select own"
  on public.runs for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "runs insert own" on public.runs;
create policy "runs insert own"
  on public.runs for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "runs delete own" on public.runs;
create policy "runs delete own"
  on public.runs for delete
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Optional cleanup: the old guided "Quick Run" activity is no longer used
-- (the app now records real walks/runs). Only run this if the activities
-- table still has a quick_run row. Never touches activity_logs history.
-- ---------------------------------------------------------------------------
-- delete from public.activities where type = 'quick_run';
