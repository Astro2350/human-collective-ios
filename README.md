# Human Culture

Human Culture is a calm SwiftUI MVP for a weekly pack of human-made culture: objects, places, artworks, textiles, manuscripts, maps, and artifacts from open-access or public-domain style sources.

## Requirements

- Xcode 26 or later
- iOS 17+
- XcodeGen (`brew install xcodegen`) if you need to regenerate the project

## Run Locally

```bash
xcodegen generate
open HumanCulture.xcodeproj
```

Select the `HumanCulture` scheme and run on an iOS simulator. The app compiles and runs without Supabase credentials by using `MockCultureRepository`.

## Supabase Setup

The app looks for Supabase values in:

- `HumanCulture/Config/Debug.xcconfig`
- `HumanCulture/Config/Release.xcconfig`

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

- `HumanCulture/App` - app entry point, onboarding gate, tab shell
- `HumanCulture/Models` - `CultureItem`, `CulturePack`, `CultureCategory`
- `HumanCulture/Repositories` - repository protocol, mock data, Supabase REST stub
- `HumanCulture/Persistence` - local saved-item persistence using `UserDefaults`
- `HumanCulture/ViewModels` - async loading and detail/saved state
- `HumanCulture/Views` - onboarding, this week, archive, saved, detail
- `HumanCulture/Components` - reusable image, card, chip, and state views

## Notes

- Onboarding completion persists with `@AppStorage`.
- Saved pieces persist locally as encoded `CultureItem` snapshots in `UserDefaults`.
- Mock content includes seven curated sample items plus two previous archive packs.
- No audio, video, performance clips, social features, likes, comments, or infinite feed are included.
