import unittest

from Scripts.find_full_year_candidates import category_for, loc_film_candidate


class ExpandedCategoryTests(unittest.TestCase):
    def test_named_human_made_categories_are_classified(self):
        examples = {
            "oil painting on canvas": "painting",
            "bronze sculpture": "sculpture",
            "modern architecture study": "architecture",
            "automobile design": "car",
            "pocket watch": "watch",
            "walnut chair": "furniture",
            "evening dress": "fashion",
            "bread recipe": "food",
            "tea service beverage": "drink",
            "wooden violin": "instrument",
            "patent prototype": "invention",
            "steam engine machine": "machine",
            "carpenter tool": "tool",
            "cinema film poster": "film",
            "sheet music": "music",
            "chess game": "game",
            "printed book": "book",
            "war memorial monument": "monument",
            "public square plaza": "public_space",
            "suspension bridge engineering": "engineering_feat",
        }

        for text, expected in examples.items():
            with self.subTest(text=text):
                self.assertEqual(category_for(text), expected)

    def test_public_domain_loc_film_becomes_a_film_candidate(self):
        candidate = loc_film_candidate({
            "id": "http://www.loc.gov/item/example-film/",
            "title": "Example Film",
            "date": "1919",
            "url": "https://www.loc.gov/item/example-film/",
            "image_url": ["https://tile.loc.gov/example.gif"],
            "contributor": ["Example Studio"],
            "location": ["united states"],
        })

        self.assertIsNotNone(candidate)
        self.assertEqual(candidate["category"], "film")
        self.assertEqual(candidate["image_url"], "https://tile.loc.gov/example.jpg")

    def test_loc_film_rejects_later_release(self):
        candidate = loc_film_candidate({
            "id": "http://www.loc.gov/item/later-film/",
            "title": "Later Film",
            "date": "1939",
            "url": "https://www.loc.gov/item/later-film/",
            "image_url": ["https://tile.loc.gov/later.gif"],
        })

        self.assertIsNone(candidate)


if __name__ == "__main__":
    unittest.main()
