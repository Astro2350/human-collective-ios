# Collective Moderation

The Collective is a chronological feed of approved, user-submitted creations. Anyone can submit without creating an account, but nothing is published automatically.

## Public submission flow

1. The app removes image metadata, normalizes the photo to JPEG, and enforces quality and size limits.
2. `community-submit` validates the photo, category, creator name, significance statement, ownership confirmation, installation identifier, and rate limits.
3. The image is stored in the private `community-submissions` bucket and its record is marked `pending`.
4. A moderator previews the work and approves or rejects it.
5. Approval copies the normalized image into the public `community-artworks` bucket and creates the sanitized feed record.
6. The iOS feed refreshes automatically while visible and also supports pull to refresh.

The anonymous app client has no insert, update, or delete privileges on community database tables or Storage buckets. Edge Functions use the service role from the server environment. Never place the service-role key in the app or commit it to Git.

## Review criteria

Approve only when all of the following are true:

- The image is clear enough to present well in the feed.
- The submission appears to be a human-made original work.
- The creator name and significance statement are appropriate for public display.
- The selected category accurately describes the submitted creation.
- The significance statement adds genuine context rather than promotion or spam.
- The image does not expose sensitive personal information.
- There is no apparent copyright, harassment, hate, sexual-content, or safety concern.

When authorship is unclear, reject the submission or request a takedown after publication. A supplied creator name is attribution, not verified identity.

## Trusted review commands

Install the Supabase CLI, sign in, and link this project to the production project. Then use:

```bash
python3 Scripts/moderate_community_submissions.py pending
python3 Scripts/moderate_community_submissions.py preview SUBMISSION_ID
python3 Scripts/moderate_community_submissions.py approve SUBMISSION_ID
python3 Scripts/moderate_community_submissions.py reject SUBMISSION_ID --note "Reason"
python3 Scripts/moderate_community_submissions.py remove SUBMISSION_ID --note "Reason"
python3 Scripts/moderate_community_submissions.py block SUBMISSION_ID
```

Approval and rejection remove the private image after the moderation record is updated. Removal deactivates the public row and deletes its public image. Blocking prevents future submissions associated with the same anonymous installation hash and deactivates that contributor's published work.

## Reports

Published cards include **Report artwork** and **Hide this creator** actions. Reports are rate-limited and stored in `community_reports` for moderation. Respond promptly by removing violating content and blocking repeat contributors when warranted.
