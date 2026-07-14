create table if not exists public.community_contributors (
  id uuid primary key default gen_random_uuid(),
  installation_hash text unique not null check (installation_hash ~ '^[0-9a-f]{64}$'),
  is_blocked boolean not null default false,
  created_at timestamp with time zone not null default now(),
  blocked_at timestamp with time zone
);

create table if not exists public.community_submissions (
  id uuid primary key default gen_random_uuid(),
  contributor_id uuid not null references public.community_contributors(id) on delete restrict,
  creator_name text not null check (char_length(btrim(creator_name)) between 2 and 60),
  significance text not null check (char_length(btrim(significance)) between 40 and 600),
  image_path text unique not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'removed')),
  rights_confirmed_at timestamp with time zone not null,
  terms_version text not null,
  submitter_ip_hash text check (submitter_ip_hash is null or submitter_ip_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamp with time zone not null default now(),
  reviewed_at timestamp with time zone,
  moderation_note text
);

create table if not exists public.community_artworks (
  id uuid primary key,
  contributor_id uuid not null references public.community_contributors(id) on delete restrict,
  creator_name text not null check (char_length(btrim(creator_name)) between 2 and 60),
  significance text not null check (char_length(btrim(significance)) between 40 and 600),
  image_path text unique not null,
  published_at timestamp with time zone not null default now(),
  is_active boolean not null default true
);

create table if not exists public.community_reports (
  id uuid primary key default gen_random_uuid(),
  artwork_id uuid not null references public.community_artworks(id) on delete cascade,
  reporter_hash text not null check (reporter_hash ~ '^[0-9a-f]{64}$'),
  reason text not null check (reason in ('inappropriate', 'stolen', 'harassment', 'spam', 'other')),
  details text check (details is null or char_length(details) <= 500),
  created_at timestamp with time zone not null default now(),
  resolved_at timestamp with time zone,
  resolution_note text,
  unique (artwork_id, reporter_hash)
);

create index if not exists community_submissions_status_created_idx
  on public.community_submissions (status, created_at desc);

create index if not exists community_submissions_contributor_created_idx
  on public.community_submissions (contributor_id, created_at desc);

create index if not exists community_submissions_ip_created_idx
  on public.community_submissions (submitter_ip_hash, created_at desc)
  where submitter_ip_hash is not null;

create index if not exists community_artworks_published_idx
  on public.community_artworks (published_at desc)
  where is_active;

create index if not exists community_reports_unresolved_idx
  on public.community_reports (created_at desc)
  where resolved_at is null;

create or replace function public.create_community_submission(
  p_submission_id uuid,
  p_installation_hash text,
  p_submitter_ip_hash text,
  p_creator_name text,
  p_significance text,
  p_image_path text,
  p_terms_version text
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_contributor public.community_contributors;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_installation_hash, 0));

  insert into public.community_contributors (installation_hash)
  values (p_installation_hash)
  on conflict (installation_hash) do update
    set installation_hash = excluded.installation_hash
  returning * into v_contributor;

  if v_contributor.is_blocked then
    raise exception using errcode = 'P0001', message = 'community_blocked';
  end if;

  if (
    select count(*)
    from public.community_submissions
    where contributor_id = v_contributor.id
      and created_at >= now() - interval '7 days'
  ) >= 3 then
    raise exception using errcode = 'P0001', message = 'community_rate_limited';
  end if;

  if p_submitter_ip_hash is not null and (
    select count(*)
    from public.community_submissions
    where submitter_ip_hash = p_submitter_ip_hash
      and created_at >= now() - interval '1 day'
  ) >= 12 then
    raise exception using errcode = 'P0001', message = 'community_rate_limited';
  end if;

  insert into public.community_submissions (
    id,
    contributor_id,
    creator_name,
    significance,
    image_path,
    rights_confirmed_at,
    terms_version,
    submitter_ip_hash
  ) values (
    p_submission_id,
    v_contributor.id,
    btrim(p_creator_name),
    btrim(p_significance),
    p_image_path,
    now(),
    p_terms_version,
    p_submitter_ip_hash
  );

  return v_contributor.id;
end;
$$;

create or replace function public.create_community_report(
  p_artwork_id uuid,
  p_reporter_hash text,
  p_reason text,
  p_details text
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended(p_reporter_hash, 0));

  if not exists (
    select 1
    from public.community_artworks
    where id = p_artwork_id and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'community_artwork_unavailable';
  end if;

  if (
    select count(*)
    from public.community_reports
    where reporter_hash = p_reporter_hash
      and created_at >= now() - interval '1 day'
  ) >= 20 then
    raise exception using errcode = 'P0001', message = 'community_rate_limited';
  end if;

  insert into public.community_reports (artwork_id, reporter_hash, reason, details)
  values (p_artwork_id, p_reporter_hash, p_reason, nullif(btrim(p_details), ''))
  on conflict (artwork_id, reporter_hash) do nothing;
end;
$$;

alter table public.community_contributors enable row level security;
alter table public.community_submissions enable row level security;
alter table public.community_artworks enable row level security;
alter table public.community_reports enable row level security;

drop policy if exists "Public read active community artworks" on public.community_artworks;
create policy "Public read active community artworks"
  on public.community_artworks
  for select
  to anon, authenticated
  using (is_active);

revoke all on public.community_contributors from anon, authenticated;
revoke all on public.community_submissions from anon, authenticated;
revoke all on public.community_reports from anon, authenticated;
revoke insert, update, delete on public.community_artworks from anon, authenticated;

grant select on public.community_artworks to anon, authenticated;
grant all on public.community_contributors to service_role;
grant all on public.community_submissions to service_role;
grant all on public.community_artworks to service_role;
grant all on public.community_reports to service_role;

revoke all on function public.create_community_submission(uuid, text, text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.create_community_report(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.create_community_submission(uuid, text, text, text, text, text, text) to service_role;
grant execute on function public.create_community_report(uuid, text, text, text) to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'community-submissions',
  'community-submissions',
  false,
  5242880,
  array['image/jpeg']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'community-artworks',
  'community-artworks',
  true,
  5242880,
  array['image/jpeg']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;
