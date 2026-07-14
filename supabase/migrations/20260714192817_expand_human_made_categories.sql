alter table public.community_submissions
  drop constraint if exists community_submissions_category_check;

alter table public.community_submissions
  add constraint community_submissions_category_check
  check (category in (
    'painting', 'sculpture', 'architecture', 'car', 'watch', 'furniture', 'fashion',
    'food', 'drink', 'instrument', 'invention', 'machine', 'tool', 'film', 'music',
    'game', 'book', 'monument', 'public_space', 'engineering_feat', 'artifact',
    'textile', 'manuscript', 'poster', 'object', 'map', 'jewelry', 'pottery', 'mask',
    'photography', 'craft', 'art', 'design', 'writing', 'other'
  ));

alter table public.community_artworks
  drop constraint if exists community_artworks_category_check;

alter table public.community_artworks
  add constraint community_artworks_category_check
  check (category in (
    'painting', 'sculpture', 'architecture', 'car', 'watch', 'furniture', 'fashion',
    'food', 'drink', 'instrument', 'invention', 'machine', 'tool', 'film', 'music',
    'game', 'book', 'monument', 'public_space', 'engineering_feat', 'artifact',
    'textile', 'manuscript', 'poster', 'object', 'map', 'jewelry', 'pottery', 'mask',
    'photography', 'craft', 'art', 'design', 'writing', 'other'
  ));

create or replace function public.create_community_submission(
  p_submission_id uuid,
  p_installation_hash text,
  p_submitter_ip_hash text,
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
  if p_category not in (
    'painting', 'sculpture', 'architecture', 'car', 'watch', 'furniture', 'fashion',
    'food', 'drink', 'instrument', 'invention', 'machine', 'tool', 'film', 'music',
    'game', 'book', 'monument', 'public_space', 'engineering_feat', 'artifact',
    'textile', 'manuscript', 'poster', 'object', 'map', 'jewelry', 'pottery', 'mask',
    'photography', 'craft', 'art', 'design', 'writing', 'other'
  ) then
    raise exception using errcode = 'P0001', message = 'community_invalid_category';
  end if;

  v_contributor_id := public.create_community_submission(
    p_submission_id,
    p_installation_hash,
    p_submitter_ip_hash,
    p_creator_name,
    p_significance,
    p_image_path,
    p_terms_version
  );

  update public.community_submissions
  set category = p_category
  where id = p_submission_id;

  return v_contributor_id;
end;
$$;

revoke all on function public.create_community_submission(uuid, text, text, text, text, text, text, text)
  from public, anon, authenticated;

grant execute on function public.create_community_submission(uuid, text, text, text, text, text, text, text)
  to service_role;
