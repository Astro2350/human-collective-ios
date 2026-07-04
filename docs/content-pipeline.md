# Content Pipeline

Human Culture should stay curated, not scraped. This foundation keeps manual editorial work clean while leaving room for a later admin tool or import script.

## Files

- `HumanCollective/Models/ContentSource.swift` defines open-access archives and collection sources.
- `HumanCollective/Models/CultureItemDraft.swift` defines pre-curation items.
- `HumanCollective/Models/GuidedCultureScene.swift` defines optional guided close-looking scenes for a curated item.
- `HumanCollective/Models/AdminSeedData.swift` defines the seed payload shape.
- `Content/admin_seed_sample.json` contains sample sources, 20 curated items, and weekly pack assignments.

## Curation Stages

1. Add or review a `content_source`.
   Record the archive name, search URL, API URL if available, rights summary, and preferred credit line.

2. Create a `draft_item`.
   Use drafts for objects that look promising but still need rights review, better source metadata, stronger writing, or image checks.

3. Promote to `curated_items`.
   A curated item should have:
   - Stable `id`
   - Title and maker, if known
   - Culture/place/date/category
   - Direct image URL
   - Source URL
   - License or rights label
   - One-sentence hook
   - Short story
   - Why-it-matters line
   - Tags and curator note
   - Optional `guided_scenes` for pieces that reward close looking

4. Assign items to `weekly_packs`.
   A pack should usually have 5 to 7 items. The first item is treated as the featured item in the app.

## JSON Format

The top-level seed file uses:

```json
{
  "schema_version": "1.0",
  "generated_at": "2026-07-04T00:00:00Z",
  "content_sources": [],
  "draft_items": [],
  "curated_items": [],
  "weekly_packs": []
}
```

Use snake_case keys so the payload stays close to Supabase table columns.

## Guided Scenes

Use `guided_scenes` only when the image can support close inspection. Good candidates have visible details, surface texture, inscriptions, gestures, construction marks, or composition changes that can be explained in plain language.

Each scene should include:

- `id`
- `title`
- `body`
- `focus_x` and `focus_y` from `0.0` to `1.0`
- `zoom`, usually between `1.0` and `2.6`
- `scene_index`

Optional fields:

- `highlight_x`, `highlight_y`, and `highlight_radius`
- `callout`
- `image_url_override`

Keep scene copy short. The app sorts by `scene_index`, uses the item image unless `image_url_override` is present, and hides the guided-view entry when an item has no scenes.

## Manual Weekly Pack Workflow

1. Pick a week key in ISO style: `YYYY-Www`, for example `2026-W30`.
2. Choose a loose editorial theme.
   Keep it human-readable, like `Work and Shelter`, `Maps and Memory`, or `Ceremony at the Table`.
3. Select 5 to 7 curated items.
   Mix categories, regions, time periods, and object scales. Avoid making the pack feel like a search result.
4. Put the strongest visual item first.
   The app uses the first `item_ids` entry as the featured piece.
5. Read the pack aloud.
   If every hook sounds the same, rewrite. Each item should have its own reason to be there.
6. Verify rights.
   Confirm source page, license label, and image URL before import.
7. Add the pack to `weekly_packs`.
   Keep item order intentional. This order becomes `culture_pack_items.position`.

## Supabase Import Mapping

The current MVP schema has:

- `culture_items`
- `culture_packs`
- `culture_pack_items`

For the current schema:

- Insert each `curated_items` entry into `culture_items`.
- Insert each `weekly_packs` entry into `culture_packs`.
- For every `weekly_packs.item_ids` entry, insert a row into `culture_pack_items` with `position` starting at `1`.
- Store `guided_scenes` as JSON on `culture_items` when present. Use an empty array when the item does not have a guided view.

`content_sources` and `draft_items` are admin-side foundation data for now. Keep them in JSON until you add private admin tables or an internal CMS. Do not expose admin draft tables to public clients.

Supabase note: public app reads should use explicit `GRANT SELECT` plus RLS read policies. Admin imports should happen from a trusted environment, not from the iOS app.

## Quality Checklist

Before an item is promoted:

- The work is public-domain, open-access, or otherwise safe to include.
- The app is not using modern copyrighted performance, audio, video, or theater clips.
- The image URL resolves directly to an image.
- The source URL opens the museum/archive/file page.
- The story is original writing, not copied from a museum label.
- The hook is short and specific.
- The item adds variety to its weekly pack.

## Suggested Import Order

1. Validate JSON.
2. Upsert `culture_items`.
3. Upsert `culture_packs`.
4. Delete and recreate `culture_pack_items` rows for the edited week.
5. Run the app against Supabase and check This Week, Archive, and Detail.

For now, do this manually or with a small trusted script later. Do not build scraping until the editorial shape of the product is stable.
