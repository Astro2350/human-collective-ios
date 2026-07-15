# Human Collective

Human Collective is a calm SwiftUI iOS app for a daily editorial view of human-made culture: objects, artifacts, artworks, architecture, textiles, manuscripts, masks, maps, and other open-access cultural pieces from around the world. A piece can be ancient or made yesterday; cultural significance, editorial quality, and usable rights matter more than age.

The app is intentionally simple. Its moderated Collective feed lets people share creations without accounts, likes, comments, recommendations, gamification, or an infinite feed.

## Requirements

- Xcode 26 or later
- iOS 17+
- XcodeGen (`brew install xcodegen`) only if you need to regenerate the Xcode project from `project.yml`

## Run Locally

```bash
xcodegen generate
open HumanCollective.xcodeproj
```

Select the `HumanCollective` scheme and run on an iPhone simulator or a signed physical iPhone target. The internal project and target names are still `HumanCollective`; the user-facing app name is Human Collective.

## Supabase Setup

The app reads Supabase values from:

- `HumanCollective/Config/Debug.xcconfig`
- `HumanCollective/Config/Release.xcconfig`

Set:

```xcconfig
SUPABASE_URL = https://your-project-ref.supabase.co
SUPABASE_ANON_KEY = your-anon-or-publishable-key
```

If either value is blank or still contains an unresolved build placeholder, the app automatically uses `MockCultureRepository`. This keeps local development and TestFlight smoke checks working without Supabase credentials.

The optional `SupabaseCultureRepository` uses the Supabase REST API against:

- `culture_packs`
- `culture_pack_items`
- `culture_items`

Anonymous community submissions use the `community-submit`, `community-status`, and `community-report` Edge Functions. Images remain private until a moderator approves them for the public `community_artworks` feed. The status endpoint only returns receipts belonging to that anonymous installation. The phone never receives the service-role key and cannot write directly to moderation tables.

Apply the suggested public read schema from:

```bash
supabase_schema.sql
```

The archive read path is prepared for a full 365-piece year. Future weekly packs can be staged in Supabase, and public app reads only expose packs whose `start_date` has arrived.

## Weekly Culture Packs

Weekly packs are curated manually. Each pack should contain a small set of cultural items with:

- title and short hook
- story and significance text
- category
- country, culture, region, date, and maker when known
- image URL
- source archive or museum
- source link
- license

Mock content lives in `HumanCollective/Repositories/MockCultureRepository.swift`. A larger sample seed payload lives in `Content/admin_seed_sample.json`.

The manual curation workflow is documented in `docs/content-pipeline.md`.

Community review and publishing are documented in `docs/community-moderation.md`.

## Full Archive In-App Purchases

Full Archive uses support-level non-consumable in-app purchases. Every level unlocks the same archive, so people can choose what works for them while still helping cover research, upkeep, and future improvements.

Configure these product IDs in App Store Connect:

- `com.sam.HumanCollective.fullArchive.access`
- `com.sam.HumanCollective.fullArchive.standard`
- `com.sam.HumanCollective.fullArchive.patron`

Suggested price ladder: Access at $0.99, Standard at $2.99, and Patron at $4.99. Keep the App Store Connect product copy consistent with the in-app language: support levels, not donations, and the same Full Archive unlock at every level.

## App Structure

- `HumanCollective/App` - app entry point, onboarding gate, tab shell
- `HumanCollective/Models` - `CultureItem`, `CulturePack`, `CultureCategory`
- `HumanCollective/Repositories` - repository protocol, mock data, Supabase REST repository
- `HumanCollective/Persistence` - local saved works, profile, exhibitions, and submission receipts using `UserDefaults`
- `HumanCollective/ViewModels` - async loading and detail/saved state
- `HumanCollective/Views` - onboarding, today, archive, Collective, profile, and detail views
- `HumanCollective/Components` - reusable images, cards, chips, state views, and image viewer

## Persistence

The Profile is private to the iPhone and requires no account. Saved pieces persist locally as encoded `CultureItem` snapshots in `UserDefaults`; personal exhibitions and submission receipts are stored alongside them. On load, Profile refreshes saved items by ID from the active repository, falls back to local snapshots when offline, and checks the private status endpoint for moderation updates.

## Known Limitations

- Community submissions require the two Edge Functions, private/public Storage buckets, and a trusted moderation environment.
- A full 365-piece archive still requires the remaining curated content to be written, rights-checked, and imported.
- Full real-device gesture QA should still be repeated on signed TestFlight builds, especially pinch zoom, double tap zoom, and memory behavior with very large source images.
- The app currently targets portrait-first iPhone usage.
