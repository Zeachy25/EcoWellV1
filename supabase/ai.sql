-- EcoWell AI assistant: chat history, daily usage, and quota helpers.
--
-- Safe to run again: every object is created with IF NOT EXISTS, and the
-- policies/functions are replaced in place.
--
-- The Flutter app only reads its own chat history and usage. The ai Edge
-- Function uses the service role to write messages and consume quota.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null check (char_length(content) between 1 and 8000),
  action text,
  created_at timestamptz not null default now()
);

-- Existing installations predate the action column, so add it in place.
alter table public.chat_messages
  add column if not exists action text;

alter table public.chat_messages
  drop constraint if exists chat_messages_action_check;

alter table public.chat_messages
  add constraint chat_messages_action_check
  check (action is null or action in ('breathing', 'grounding'));

create index if not exists chat_messages_user_created_idx
  on public.chat_messages (user_id, created_at desc);

create table if not exists public.ai_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  usage_date date not null default current_date,
  message_count integer not null default 0 check (message_count >= 0),
  primary key (user_id, usage_date)
);

alter table public.chat_messages enable row level security;
alter table public.ai_usage enable row level security;

-- Users may read their own chat and usage. They cannot insert, update, or
-- delete directly; the Edge Function owns those writes.
drop policy if exists "Users read own chat messages" on public.chat_messages;
create policy "Users read own chat messages"
  on public.chat_messages for select
  using (auth.uid() = user_id);

drop policy if exists "Users read own ai usage" on public.ai_usage;
create policy "Users read own ai usage"
  on public.ai_usage for select
  using (auth.uid() = user_id);

grant select on public.chat_messages to authenticated;
grant select on public.ai_usage to authenticated;

-- ---------------------------------------------------------------------------
-- Quota helpers (service role only)
-- ---------------------------------------------------------------------------

create or replace function public.consume_ai_quota(
  p_user_id uuid,
  p_limit integer default 30
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
  v_limit integer := greatest(coalesce(p_limit, 30), 1);
begin
  insert into public.ai_usage (user_id, usage_date, message_count)
  values (p_user_id, current_date, 1)
  on conflict (user_id, usage_date)
  do update set message_count = public.ai_usage.message_count + 1
  returning message_count into v_count;

  if v_count > v_limit then
    update public.ai_usage
      set message_count = greatest(message_count - 1, 0)
      where user_id = p_user_id and usage_date = current_date;
    return false;
  end if;

  return true;
end;
$$;

create or replace function public.refund_ai_quota(p_user_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.ai_usage
    set message_count = greatest(message_count - 1, 0)
    where user_id = p_user_id and usage_date = current_date;
$$;

revoke all on function public.consume_ai_quota(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.refund_ai_quota(uuid)
  from public, anon, authenticated;
grant execute on function public.consume_ai_quota(uuid, integer) to service_role;
grant execute on function public.refund_ai_quota(uuid) to service_role;
