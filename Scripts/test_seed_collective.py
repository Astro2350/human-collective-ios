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


if __name__ == "__main__":
    unittest.main()
