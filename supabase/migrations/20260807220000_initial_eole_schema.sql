create extension if not exists pgcrypto;

create type public.session_status as enum ('completed', 'stopped');
create type public.breathing_pace as enum ('slow', 'normal', 'fast');
create type public.music_track as enum ('glacier', 'lagon', 'aurore');

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null check (char_length(first_name) between 1 and 60),
  username text not null unique check (username ~ '^[a-z0-9._-]{3,30}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  music_track public.music_track not null default 'glacier',
  music_volume smallint not null default 32 check (music_volume between 0 and 100),
  breath_volume smallint not null default 72 check (breath_volume between 0 and 100),
  haptics_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status public.session_status not null,
  planned_rounds smallint not null check (planned_rounds between 1 and 8),
  breaths_per_round smallint not null check (breaths_per_round between 10 and 60),
  pace public.breathing_pace not null,
  started_at timestamptz not null,
  completed_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (completed_at >= started_at)
);

create table public.rounds (
  id bigint generated always as identity primary key,
  session_id uuid not null references public.sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  round_index smallint not null check (round_index between 1 and 8),
  breaths_completed smallint not null check (breaths_completed between 10 and 60),
  retention_seconds integer not null check (retention_seconds between 1 and 3600),
  created_at timestamptz not null default now(),
  unique (session_id, round_index)
);

create index sessions_user_completed_idx on public.sessions (user_id, completed_at desc);
create index rounds_user_session_idx on public.rounds (user_id, session_id);

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.sessions enable row level security;
alter table public.rounds enable row level security;

create policy "profiles_select_own" on public.profiles for select using ((select auth.uid()) = user_id);
create policy "profiles_update_own" on public.profiles for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "settings_select_own" on public.user_settings for select using ((select auth.uid()) = user_id);
create policy "settings_insert_own" on public.user_settings for insert with check ((select auth.uid()) = user_id);
create policy "settings_update_own" on public.user_settings for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "sessions_select_own" on public.sessions for select using ((select auth.uid()) = user_id);
create policy "sessions_insert_own" on public.sessions for insert with check ((select auth.uid()) = user_id);
create policy "rounds_select_own" on public.rounds for select using ((select auth.uid()) = user_id);
create policy "rounds_insert_own" on public.rounds for insert with check (
  (select auth.uid()) = user_id
  and exists (select 1 from public.sessions where sessions.id = session_id and sessions.user_id = (select auth.uid()))
);

create or replace function public.save_breath_session(
  p_session_id uuid,
  p_status public.session_status,
  p_planned_rounds smallint,
  p_breaths_per_round smallint,
  p_pace public.breathing_pace,
  p_started_at timestamptz,
  p_completed_at timestamptz,
  p_rounds jsonb
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  item jsonb;
  owner_id uuid := auth.uid();
begin
  if owner_id is null then
    raise exception 'authentication required';
  end if;

  insert into public.sessions (id, user_id, status, planned_rounds, breaths_per_round, pace, started_at, completed_at)
  values (p_session_id, owner_id, p_status, p_planned_rounds, p_breaths_per_round, p_pace, p_started_at, p_completed_at);

  for item in select value from jsonb_array_elements(p_rounds)
  loop
    insert into public.rounds (session_id, user_id, round_index, breaths_completed, retention_seconds)
    values (
      p_session_id,
      owner_id,
      (item ->> 'roundIndex')::smallint,
      (item ->> 'breathsCompleted')::smallint,
      (item ->> 'retentionSeconds')::integer
    );
  end loop;
end;
$$;

revoke all on function public.save_breath_session(uuid, public.session_status, smallint, smallint, public.breathing_pace, timestamptz, timestamptz, jsonb) from public;
grant execute on function public.save_breath_session(uuid, public.session_status, smallint, smallint, public.breathing_pace, timestamptz, timestamptz, jsonb) to authenticated;

grant select, update on public.profiles to authenticated;
grant select, insert, update on public.user_settings to authenticated;
grant select, insert on public.sessions to authenticated;
grant select, insert on public.rounds to authenticated;
grant usage, select on sequence public.rounds_id_seq to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (user_id, first_name, username)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'first_name'), ''), 'Utilisateur'),
    lower(coalesce(nullif(trim(new.raw_user_meta_data ->> 'username'), ''), 'user-' || substr(new.id::text, 1, 8)))
  );
  insert into public.user_settings (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
