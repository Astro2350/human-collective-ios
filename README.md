# Human Collective

Human Collective is a calm SwiftUI MVP for a weekly pack of human-made culture: objects, places, artworks, textiles, manuscripts, maps, and artifacts from open-access or public-domain style sources.

## Requirements

- Xcode 26 or later
- iOS 17+
- XcodeGen (`brew install xcodegen`) if you need to regenerate the project

## Run Locally

```bash
xcodegen generate
open HumanCollective.xcodeproj
```

Select the `HumanCollective` scheme and run on an iOS simulator. The app compiles and runs without Supabase credentials by using `MockCultureRepository`.

## Supabase Setup

The app looks for Supabase values in:

- `HumanCollective/Config/Debug.xcconfig`
- `HumanCollective/Config/Release.xcconfig`

Set:

```xcconfig
SUPABASE_URL = https://your-project-ref.supabase.co
SUPABASE_ANON_KEY = your-anon-or-publishable-key
```

Leave them blank to keep using mock data. The optional `SupabaseCultureRepository` uses the Supabase REST API against `culture_packs`, `culture_pack_items`, and `culture_items`.

Apply the suggested public read schema from:

```bash
supabase_schema.sql
```

## Structure

- `HumanCollective/App` - app entry point, onboarding gate, tab shell
- `HumanCollective/Models` - `CultureItem`, `CulturePack`, `CultureCategory`
- `HumanCollective/Repositories` - repository protocol, mock data, Supabase REST stub
- `HumanCollective/Persistence` - local saved-item persistence using `UserDefaults`
- `HumanCollective/ViewModels` - async loading and detail/saved state
- `HumanCollective/Views` - onboarding, this week, archive, saved, detail
- `HumanCollective/Components` - reusable image, card, chip, and state views

## Notes

- Onboarding completion persists with `@AppStorage`.
- Saved pieces persist locally as encoded `CultureItem` snapshots in `UserDefaults`.
- Mock content includes seven curated sample items plus two previous archive packs.
- No audio, video, performance clips, social features, likes, comments, or infinite feed are included.

## Content Pipeline

- Manual curation guide: `docs/content-pipeline.md`
- Sample admin seed payload: `Content/admin_seed_sample.json`

The seed format is a foundation for later Supabase import scripts or a private admin tool. It does not add scraping or public admin writes to the iOS app.
