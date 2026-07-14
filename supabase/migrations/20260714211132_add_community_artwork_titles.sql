alter table public.community_submissions
  add column if not exists title text not null default 'Untitled';

alter table public.community_artworks
  add column if not exists title text not null default 'Untitled';

alter table public.community_submissions
  drop constraint if exists community_submissions_title_check;

alter table public.community_submissions
  add constraint community_submissions_title_check
  check (char_length(btrim(title)) between 2 and 120);

alter table public.community_artworks
  drop constraint if exists community_artworks_title_check;

alter table public.community_artworks
  add constraint community_artworks_title_check
  check (char_length(btrim(title)) between 2 and 120);

create or replace function public.create_community_submission(
  p_submission_id uuid,
  p_installation_hash text,
  p_submitter_ip_hash text,
  p_title text,
  p_creator_name text,
  p_significance text,
  p_image_path text,
  p_terms_version text,
  p_category text
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_contributor_id uuid;
begin
  if p_title is null or char_length(btrim(p_title)) not between 2 and 120 then
    raise exception using errcode = 'P0001', message = 'community_invalid_title';
  end if;

  v_contributor_id := public.create_community_submission(
    p_submission_id,
    p_installation_hash,
    p_submitter_ip_hash,
    p_creator_name,
    p_significance,
    p_image_path,
    p_terms_version,
    p_category
  );

  update public.community_submissions
  set title = btrim(p_title)
  where id = p_submission_id;

  return v_contributor_id;
end;
$$;

revoke all on function public.create_community_submission(uuid, text, text, text, text, text, text, text, text)
  from public, anon, authenticated;

grant execute on function public.create_community_submission(uuid, text, text, text, text, text, text, text, text)
  to service_role;
