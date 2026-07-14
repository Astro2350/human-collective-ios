alter table public.community_artworks
  add column if not exists seed_key text,
  add column if not exists source_name text,
  add column if not exists source_url text,
  add column if not exists rights_label text;

alter table public.community_artworks
  drop constraint if exists community_artworks_seed_key_check;

alter table public.community_artworks
  add constraint community_artworks_seed_key_check
  check (seed_key is null or char_length(btrim(seed_key)) between 3 and 160);

alter table public.community_artworks
  drop constraint if exists community_artworks_source_url_check;

alter table public.community_artworks
  add constraint community_artworks_source_url_check
  check (source_url is null or source_url ~ '^https://');

create unique index if not exists community_artworks_seed_key_idx
  on public.community_artworks (seed_key)
  where seed_key is not null;
