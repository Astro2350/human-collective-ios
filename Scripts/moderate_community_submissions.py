#!/usr/bin/env python3
"""Review and publish Human Collective submissions through the linked Supabase CLI."""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
import tempfile
import uuid


class CommunityAdminClient:
    def pending(self) -> list[dict]:
        return self._query(
            """
            select id, contributor_id, title, creator_name, significance, category, image_path, created_at
            from public.community_submissions
            where status = 'pending'
            order by created_at;
            """
        )

    def submission(self, submission_id: uuid.UUID) -> dict:
        rows = self._query(
            f"""
            select id, contributor_id, title, creator_name, significance, category, image_path, status, created_at
            from public.community_submissions
            where id = '{submission_id}'::uuid
            limit 1;
            """
        )
        if not rows:
            raise RuntimeError("Submission not found.")
        return rows[0]

    def preview(self, submission_id: uuid.UUID, output: pathlib.Path) -> None:
        submission = self.submission(submission_id)
        self._storage(
            "cp",
            f"ss:///community-submissions/{submission['image_path']}",
            str(output),
        )

    def approve(self, submission_id: uuid.UUID) -> None:
        submission = self.submission(submission_id)
        if submission["status"] == "approved":
            return
        if submission["status"] != "pending":
            raise RuntimeError(f"Submission is {submission['status']}, not pending.")

        public_path = f"{submission_id}.jpg"
        with tempfile.TemporaryDirectory(prefix="human-collective-review-") as directory:
            local_image = pathlib.Path(directory) / public_path
            self._storage(
                "cp",
                f"ss:///community-submissions/{submission['image_path']}",
                str(local_image),
            )
            self._storage(
                "cp",
                str(local_image),
                f"ss:///community-artworks/{public_path}",
                "--content-type",
                "image/jpeg",
            )

            try:
                self._execute(
                    f"""
                    insert into public.community_artworks (
                      id, contributor_id, title, creator_name, significance, category, image_path, published_at, is_active
                    )
                    select id, contributor_id, title, creator_name, significance, category, '{public_path}', now(), true
                    from public.community_submissions
                    where id = '{submission_id}'::uuid
                    on conflict (id) do update
                    set contributor_id = excluded.contributor_id,
                        title = excluded.title,
                        creator_name = excluded.creator_name,
                        significance = excluded.significance,
                        category = excluded.category,
                        image_path = excluded.image_path,
                        published_at = excluded.published_at,
                        is_active = true;

                    update public.community_submissions
                    set status = 'approved', reviewed_at = now(), moderation_note = null
                    where id = '{submission_id}'::uuid;
                    """
                )
            except RuntimeError:
                self._remove("community-artworks", public_path, warn_only=True)
                raise
        self._remove("community-submissions", submission["image_path"], warn_only=True)

    def reject(self, submission_id: uuid.UUID, note: str | None) -> None:
        submission = self.submission(submission_id)
        self._set_status(submission_id, "rejected", note)
        self._remove("community-submissions", submission["image_path"], warn_only=True)

    def remove(self, submission_id: uuid.UUID, note: str | None) -> None:
        submission = self.submission(submission_id)
        self._execute(
            f"""
            update public.community_artworks
            set is_active = false
            where id = '{submission_id}'::uuid;
            """
        )
        self._set_status(submission_id, "removed", note)
        self._remove("community-artworks", f"{submission_id}.jpg", warn_only=True)

    def block_contributor(self, submission_id: uuid.UUID) -> None:
        submission = self.submission(submission_id)
        contributor_id = uuid.UUID(submission["contributor_id"])
        artwork_rows = self._query(
            f"""
            select image_path
            from public.community_artworks
            where contributor_id = '{contributor_id}'::uuid and is_active;
            """
        )
        self._execute(
            f"""
            update public.community_contributors
            set is_blocked = true, blocked_at = now()
            where id = '{contributor_id}'::uuid;

            update public.community_artworks
            set is_active = false
            where contributor_id = '{contributor_id}'::uuid;
            """
        )
        for artwork in artwork_rows:
            self._remove("community-artworks", artwork["image_path"], warn_only=True)

    def _set_status(self, submission_id: uuid.UUID, status: str, note: str | None) -> None:
        note_sql = "null" if note is None else self._literal(note)
        self._execute(
            f"""
            update public.community_submissions
            set status = '{status}', reviewed_at = now(), moderation_note = {note_sql}
            where id = '{submission_id}'::uuid;
            """
        )

    def _remove(self, bucket: str, path: str, warn_only: bool) -> None:
        try:
            self._storage("rm", f"ss:///{bucket}/{path}")
        except RuntimeError as error:
            if not warn_only:
                raise
            print(f"Warning: {error}", file=sys.stderr)

    def _query(self, sql: str) -> list[dict]:
        output = self._run(
            "db",
            "query",
            "--linked",
            "--agent=no",
            "--output",
            "json",
            sql,
        )
        parsed = json.loads(output)
        if not isinstance(parsed, list):
            raise RuntimeError("Supabase returned an unexpected response.")
        return parsed

    def _execute(self, sql: str) -> None:
        self._run("db", "query", "--linked", "--agent=no", "--output", "json", sql)

    def _storage(self, command: str, *arguments: str) -> None:
        self._run("storage", command, *arguments, "--experimental", "--yes")

    @staticmethod
    def _literal(value: str) -> str:
        return "'" + value.replace("'", "''") + "'"

    @staticmethod
    def _run(*arguments: str) -> str:
        try:
            result = subprocess.run(
                ["supabase", *arguments],
                check=True,
                capture_output=True,
                text=True,
            )
        except FileNotFoundError as error:
            raise RuntimeError("The Supabase CLI is not installed.") from error
        except subprocess.CalledProcessError as error:
            detail = error.stderr.strip() or error.stdout.strip() or "Unknown Supabase CLI error."
            raise RuntimeError(detail) from error
        return result.stdout.strip()


def print_pending(rows: list[dict]) -> None:
    if not rows:
        print("No pending community submissions.")
        return
    for row in rows:
        print(f"{row['id']}  {row['created_at']}  {row['title']} — {row['creator_name']}  [{row['category']}]")
        print(f"  {row['significance']}")


def submission_id(value: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("Submission IDs must be UUIDs.") from error


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("pending", help="List pending submissions")

    preview = commands.add_parser("preview", help="Download one pending image for review")
    preview.add_argument("submission_id", type=submission_id)
    preview.add_argument("--output", type=pathlib.Path)

    approve = commands.add_parser("approve", help="Publish a pending submission")
    approve.add_argument("submission_id", type=submission_id)

    reject = commands.add_parser("reject", help="Reject a pending submission")
    reject.add_argument("submission_id", type=submission_id)
    reject.add_argument("--note")

    remove = commands.add_parser("remove", help="Remove a published submission")
    remove.add_argument("submission_id", type=submission_id)
    remove.add_argument("--note")

    block = commands.add_parser("block", help="Block a contributor and hide their published work")
    block.add_argument("submission_id", type=submission_id)

    args = parser.parse_args()
    client = CommunityAdminClient()

    if args.command == "pending":
        print_pending(client.pending())
    elif args.command == "preview":
        output = args.output or pathlib.Path(tempfile.gettempdir()) / f"human-collective-{args.submission_id}.jpg"
        client.preview(args.submission_id, output)
        print(output.resolve())
    elif args.command == "approve":
        client.approve(args.submission_id)
        print(f"Approved {args.submission_id}.")
    elif args.command == "reject":
        client.reject(args.submission_id, args.note)
        print(f"Rejected {args.submission_id}.")
    elif args.command == "remove":
        client.remove(args.submission_id, args.note)
        print(f"Removed {args.submission_id}.")
    elif args.command == "block":
        client.block_contributor(args.submission_id)
        print(f"Blocked the contributor for {args.submission_id}.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(f"Error: {error}", file=sys.stderr)
        raise SystemExit(1)
