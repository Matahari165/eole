begin;

create extension if not exists pgcrypto;

do $$
begin
  create type public.session_status as enum ('completed', 'stopped');
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type public.breathing_pace as enum ('slow', 'normal', 'fast');
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type public.music_track as enum ('pluie', 'ocean', 'foret');
exception
  when duplicate_object then null;
end
$$;

create table if not exists public.personal_profile (
  id smallint primary key default 1 check (id = 1),
  first_name text not null check (char_length(first_name) between 1 and 60),
  username text not null check (username ~ '^[a-z0-9._-]{3,30}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.personal_settings (
  id smallint primary key default 1 check (id = 1),
  music_track public.music_track not null default 'pluie',
  music_volume smallint not null default 32 check (music_volume between 0 and 100),
  breath_volume smallint not null default 72 check (breath_volume between 0 and 100),
  haptics_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.personal_sessions (
  id uuid primary key default gen_random_uuid(),
  status public.session_status not null,
  planned_rounds smallint not null check (planned_rounds between 1 and 8),
  breaths_per_round smallint not null check (breaths_per_round between 10 and 60),
  pace public.breathing_pace not null,
  started_at timestamptz not null,
  completed_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (completed_at >= started_at)
);

create table if not exists public.personal_rounds (
  id bigint generated always as identity primary key,
  session_id uuid not null references public.personal_sessions(id) on delete cascade,
  round_index smallint not null check (round_index between 1 and 8),
  breaths_completed smallint not null check (breaths_completed between 10 and 60),
  retention_seconds integer not null check (retention_seconds between 1 and 3600),
  created_at timestamptz not null default now(),
  unique (session_id, round_index)
);

create index if not exists personal_sessions_completed_idx on public.personal_sessions (completed_at desc);
create index if not exists personal_rounds_session_idx on public.personal_rounds (session_id);

insert into public.personal_profile (id, first_name, username)
values (1, 'Jeremy', 'jeremy')
on conflict (id) do nothing;

insert into public.personal_settings (id)
values (1)
on conflict (id) do nothing;

create or replace function public.save_personal_breath_session(
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
begin
  insert into public.personal_sessions (id, status, planned_rounds, breaths_per_round, pace, started_at, completed_at)
  values (p_session_id, p_status, p_planned_rounds, p_breaths_per_round, p_pace, p_started_at, p_completed_at)
  on conflict (id) do update
  set status = excluded.status,
      planned_rounds = excluded.planned_rounds,
      breaths_per_round = excluded.breaths_per_round,
      pace = excluded.pace,
      started_at = excluded.started_at,
      completed_at = excluded.completed_at;

  delete from public.personal_rounds where session_id = p_session_id;

  for item in select value from jsonb_array_elements(p_rounds)
  loop
    insert into public.personal_rounds (session_id, round_index, breaths_completed, retention_seconds)
    values (
      p_session_id,
      (item ->> 'roundIndex')::smallint,
      (item ->> 'breathsCompleted')::smallint,
      (item ->> 'retentionSeconds')::integer
    );
  end loop;
end;
$$;

revoke all privileges on public.personal_profile from public, authenticated;
revoke all privileges on public.personal_settings from public, authenticated;
revoke all privileges on public.personal_sessions from public, authenticated;
revoke all privileges on public.personal_rounds from public, authenticated;
revoke all privileges on sequence public.personal_rounds_id_seq from public, authenticated;
revoke execute on function public.save_personal_breath_session(uuid, public.session_status, smallint, smallint, public.breathing_pace, timestamptz, timestamptz, jsonb) from public, authenticated;

commit;
