import json
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest import mock


sys.path.insert(0, str(Path(__file__).resolve().parent))
import post_daily_instagram as subject  # noqa: E402


class PostingHardeningTests(unittest.TestCase):
    def test_classifies_meta_account_lock(self):
        error = subject.classify_http_error(
            "instagram",
            "preflight",
            400,
            json.dumps(
                {
                    "error": {
                        "message": "API access blocked.",
                        "type": "OAuthException",
                        "code": 200,
                    }
                }
            ),
        )

        self.assertEqual(error.category, "meta_account_locked")
        self.assertFalse(error.retry_safe)
        self.assertIn("Interactive account confirmation", str(error))

    def test_invalid_state_refuses_duplicate_risk(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            path.write_text("{not-json", encoding="utf-8")

            with self.assertRaises(subject.PostingError) as caught:
                subject.load_state(path)

        self.assertEqual(caught.exception.category, "posting_state_invalid")

    def test_wait_for_container_polls_until_finished(self):
        responses = [
            {"status_code": "IN_PROGRESS"},
            {"status_code": "FINISHED", "id": "container-1"},
        ]
        with mock.patch.object(subject, "request_json", side_effect=responses) as request:
            result = subject.wait_for_container(
                "https://graph.instagram.com/v25.0",
                {"Authorization": "Bearer token"},
                "container-1",
                timeout_seconds=1,
                poll_seconds=0,
            )

        self.assertEqual(result["status_code"], "FINISHED")
        self.assertEqual(request.call_count, 2)

    def test_publish_network_failure_is_ambiguous(self):
        with mock.patch.object(
            subject.urllib.request,
            "urlopen",
            side_effect=urllib.error.URLError("connection reset"),
        ):
            with self.assertRaises(subject.PostingError) as caught:
                subject.request_json(
                    "POST",
                    "https://graph.instagram.com/v25.0/account/media_publish",
                    data={"creation_id": "container-1"},
                    service="instagram",
                    operation="publish",
                    may_have_posted=True,
                )

        self.assertTrue(caught.exception.may_have_posted)
        self.assertFalse(caught.exception.retry_safe)

    def test_exact_caption_reconciles_existing_media(self):
        with mock.patch.object(
            subject,
            "request_json",
            return_value={
                "data": [
                    {"id": "older", "caption": "Something else"},
                    {"id": "match", "caption": "Exact caption"},
                ]
            },
        ):
            media = subject.find_matching_recent_media(
                "account",
                "https://graph.instagram.com/v25.0",
                {"Authorization": "Bearer token"},
                "Exact caption",
            )

        self.assertEqual(media["id"], "match")

    def test_reconciliation_ignores_old_matching_caption(self):
        with mock.patch.object(
            subject,
            "request_json",
            return_value={
                "data": [
                    {
                        "id": "old-match",
                        "caption": "Exact caption",
                        "timestamp": "2026-01-01T12:00:00+00:00",
                    }
                ]
            },
        ):
            media = subject.find_matching_recent_media(
                "account",
                "https://graph.instagram.com/v25.0",
                {"Authorization": "Bearer token"},
                "Exact caption",
                "2026-07-11T12:00:00+00:00",
            )

        self.assertIsNone(media)

    def test_legacy_media_id_counts_as_published(self):
        self.assertTrue(subject.state_entry_is_published({"instagram_media_id": "media-1"}))

    def test_preflight_rejects_account_mismatch(self):
        with mock.patch.object(
            subject,
            "request_json",
            return_value={"id": "different", "username": "other", "account_type": "BUSINESS"},
        ):
            with self.assertRaises(subject.PostingError) as caught:
                subject.preflight_instagram(
                    "expected",
                    "https://graph.instagram.com/v25.0",
                    {"Authorization": "Bearer token"},
                )

        self.assertEqual(caught.exception.category, "instagram_account_mismatch")


if __name__ == "__main__":
    unittest.main()
