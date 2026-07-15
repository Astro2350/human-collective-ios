import copy
import json
import unittest

from Scripts import seed_collective


class SeedCollectiveTests(unittest.TestCase):
    def test_manifest_has_three_unique_items_in_every_category(self):
        manifest = json.loads(seed_collective.MANIFEST_PATH.read_text())

        items = seed_collective.validate_manifest(manifest)

        self.assertEqual(len(items), 60)
        self.assertEqual(
            len({(item["provider"], str(item["source_id"])) for item in items}),
            60,
        )

    def test_title_matching_ignores_catalog_punctuation_and_stop_words(self):
        expected = seed_collective.title_keywords("Automobiles in a Full Parking Lot")
        actual = seed_collective.title_keywords("Automobiles. Automobiles in full parking lot")

        self.assertTrue(expected.issubset(actual))

    def test_manifest_rejects_titles_outside_database_limits(self):
        manifest = json.loads(seed_collective.MANIFEST_PATH.read_text())
        invalid_manifest = copy.deepcopy(manifest)
        invalid_manifest["items"][0]["title"] = " "

        with self.assertRaisesRegex(RuntimeError, "Invalid title length"):
            seed_collective.validate_manifest(invalid_manifest)


if __name__ == "__main__":
    unittest.main()
