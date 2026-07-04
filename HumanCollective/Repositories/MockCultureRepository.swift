import Foundation

struct MockCultureRepository: CultureRepository {
    private let packs: [CulturePack]

    init() {
        self.packs = Self.makePacks()
    }

    func fetchCurrentPack() async throws -> CulturePack {
        try await Task.sleep(nanoseconds: 250_000_000)
        guard let pack = packs.first else {
            throw CultureRepositoryError.emptyResponse
        }
        return pack
    }

    func fetchArchivePacks() async throws -> [CulturePack] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return Array(packs.dropFirst())
    }

    func fetchPack(weekKey: String) async throws -> CulturePack? {
        try await Task.sleep(nanoseconds: 150_000_000)
        return packs.first { $0.weekKey == weekKey }
    }

    func fetchItems(ids: Set<String>) async throws -> [CultureItem] {
        try await Task.sleep(nanoseconds: 150_000_000)
        guard !ids.isEmpty else { return [] }

        return packs
            .flatMap(\.items)
            .filter { ids.contains($0.id) }
    }

    private static func makePacks() -> [CulturePack] {
        [
            makePack(
                weekOffset: 0,
                title: "This Week in Human Culture",
                subtitle: "A blue hippo, a Noh mask, tilework, a theatre, a textile, a manuscript, and a map.",
                items: currentItems
            ),
            makePack(
                weekOffset: -1,
                title: "Tools for Seeing",
                subtitle: "Maps, vessels, and surfaces.",
                items: previousItemsOne
            ),
            makePack(
                weekOffset: -2,
                title: "Ceremony and Rooms",
                subtitle: "Ritual objects and everyday beauty.",
                items: previousItemsTwo
            )
        ]
    }

    private static func makePack(
        weekOffset: Int,
        title: String,
        subtitle: String,
        items: (String) -> [CultureItem]
    ) -> CulturePack {
        let calendar = Calendar.cultureCalendar
        let now = Date()
        let shifted = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: now) ?? now
        let start = calendar.dateInterval(of: .weekOfYear, for: shifted)?.start ?? shifted
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? shifted
        let weekKey = start.cultureWeekKey

        return CulturePack(
            id: "pack-\(weekKey)",
            weekKey: weekKey,
            title: title,
            subtitle: subtitle,
            startDate: start,
            endDate: end,
            items: items(weekKey)
        )
    }

    private static func currentItems(weekKey: String) -> [CultureItem] {
        [
            CultureItem(
                id: "\(weekKey)-faience-hippopotamus",
                title: "Blue Faience Hippopotamus",
                maker: nil,
                culture: "Ancient Egyptian",
                country: "Egypt",
                region: "Middle Kingdom",
                dateDisplay: "c. 1961-1878 BCE",
                category: .artifact,
                imageURL: "https://commons.wikimedia.org/wiki/Special:Redirect/file/Standing_Hippopotamus_MET_DP248993.jpg?width=900",
                sourceName: "The Metropolitan Museum of Art",
                sourceURL: "https://www.metmuseum.org/art/collection/search/544227",
                license: "Public domain / Met Open Access",
                hook: "A blue river animal with a marsh painted on its back.",
                story: """
                This small hippopotamus was made for a tomb, but it feels startlingly alive: bright blue, rounded, and patterned with lotus plants that place it back in the Nile marshes. Ancient Egyptian faience was not clay in the usual sense; it was a quartz-rich material that could glow with glassy color after firing. The animal was powerful and dangerous in life, yet here it becomes a companion for renewal. Its painted plants make the body feel like water, reeds, and sunlight compressed into one object. The charm is immediate, but the idea underneath is serious: the world of the living could be carried carefully into the next one.
                """,
                whyItMatters: "It turns a feared animal into a hopeful object, showing how craft, belief, and affection can meet in a single handmade form.",
                latitude: 27.4400,
                longitude: 30.8300,
                weekKey: weekKey,
                guidedScenes: blueHippoGuidedScenes()
            ),
            CultureItem(
                id: "\(weekKey)-noh-hannya-mask",
                title: "Noh Mask of the Hannya Type",
                maker: nil,
                culture: "Japanese",
                country: "Japan",
                region: "Edo period",
                dateDisplay: "17th-18th century",
                category: .mask,
                imageURL: "https://commons.wikimedia.org/wiki/Special:Redirect/file/Noh_Mask_Hannya_type.jpg?width=900",
                sourceName: "Wikimedia Commons",
                sourceURL: "https://commons.wikimedia.org/wiki/File:Noh_Mask_Hannya_type.jpg",
                license: "Open access image",
                hook: "A face that changes with the angle of the light.",
                story: """
                In Noh theater, a mask is never simply a disguise. The carved face is a quiet instrument, designed to change as the performer moves through space. Tilted upward, a mask can seem brighter and more open; lowered, it can feel shadowed, wounded, or severe. The hannya type suggests a spirit transformed by jealousy or grief, but its power comes from restraint rather than exaggeration. The actor's body, the stage light, and the audience's attention complete the expression. Nothing here is casual. A fixed face becomes emotionally alive because generations of performers learned how little movement it takes to change what we see.
                """,
                whyItMatters: "It shows how performance can live inside an object, waiting for gesture, light, and patience to release it.",
                latitude: 35.6764,
                longitude: 139.6500,
                weekKey: weekKey,
                guidedScenes: nohMaskGuidedScenes()
            ),
            CultureItem(
                id: "\(weekKey)-moroccan-zellige",
                title: "Zellige Tilework, Ben Youssef Madrasa",
                maker: "Unknown Moroccan artisans",
                culture: "Moroccan",
                country: "Morocco",
                region: "Marrakesh",
                dateDisplay: "16th century tradition",
                category: .architecture,
                imageURL: "https://commons.wikimedia.org/wiki/Special:Redirect/file/%D9%86%D8%B8%D8%B1%D8%A9_%D9%85%D9%82%D8%B1%D8%A8%D8%A9_%D9%84%D9%84%D8%B2%D9%84%D9%8A%D8%AC_%D9%81%D9%8A_%D9%85%D8%AF%D8%B1%D8%B3%D8%A9_%D8%A7%D8%A8%D9%86_%D9%8A%D9%88%D8%B3%D9%81.jpeg?width=900",
                sourceName: "Wikimedia Commons",
                sourceURL: "https://commons.wikimedia.org/wiki/File:%D9%86%D8%B8%D8%B1%D8%A9_%D9%85%D9%82%D8%B1%D8%A8%D8%A9_%D9%84%D9%84%D8%B2%D9%84%D9%8A%D8%AC_%D9%81%D9%8A_%D9%85%D8%AF%D8%B1%D8%B3%D8%A9_%D8%A7%D8%A8%D9%86_%D9%8A%D9%88%D8%B3%D9%81.jpeg",
                license: "Open access image",
                hook: "Hand-cut tiles settle into a calm geometry.",
                story: """
                Zellige is made from small glazed pieces cut by hand and assembled into geometric patterns. In a place like the Ben Youssef Madrasa, the surface is not decoration added at the end; it shapes the whole feeling of the room. Pattern slows the eye. Repetition becomes a form of attention. The work depends on mathematics, apprenticeship, and touch: each piece must be made separately, then placed so the larger rhythm can appear. The result feels both precise and generous. No single tile explains the pattern, but every tile is needed. That is part of its quiet lesson.
                """,
                whyItMatters: "It makes collective craft visible, turning architecture into a field of patience, proportion, and shared skill.",
                latitude: 31.6325,
                longitude: -7.9867,
                weekKey: weekKey
            ),
            CultureItem(
                id: "\(weekKey)-epidaurus-theatre",
                title: "Ancient Theatre of Epidaurus",
                maker: "Attributed to Polykleitos the Younger",
                culture: "Greek",
                country: "Greece",
                region: "Argolis",
                dateDisplay: "late 4th century BCE",
                category: .architecture,
                imageURL: "https://commons.wikimedia.org/wiki/Special:Redirect/file/The_great_theater_of_Epidaurus%2C_designed_by_Polykleitos_the_Younger_in_the_4th_century_BC%2C_Sanctuary_of_Asklepeios_at_Epidaurus%2C_Greece_%2814015010416%29.jpg?width=900",
                sourceName: "Wikimedia Commons",
                sourceURL: "https://commons.wikimedia.org/wiki/File:The_great_theater_of_Epidaurus,_designed_by_Polykleitos_the_Younger_in_the_4th_century_BC,_Sanctuary_of_Asklepeios_at_Epidaurus,_Greece_(14015010416).jpg",
                license: "CC BY 2.0",
                hook: "A hillside shaped so a crowd could listen together.",
                story: """
                The theatre at Epidaurus is often admired for its acoustics, but its deeper beauty is social. Stone seats curve into the hillside, gathering thousands of people around an open circle. The setting belonged to a sanctuary of healing, where drama, music, ritual, and recovery were part of a larger civic experience. Architecture here does not compete with the landscape; it organizes attention inside it. From the upper rows, the theatre reads like a quiet drawing cut into the earth. It reminds us that culture is not only what is performed, but the space a community builds to witness something together.
                """,
                whyItMatters: "It shows architecture as a public technology for listening, gathering, and making shared memory.",
                latitude: 37.5961,
                longitude: 23.0792,
                weekKey: weekKey
            ),
            CultureItem(
                id: "\(weekKey)-paracas-mantle",
                title: "Nasca-Paracas Mantle",
                maker: "Unknown Andean weavers",
                culture: "Nasca-Paracas",
                country: "Peru",
                region: "South Coast",
                dateDisplay: "1-100 CE",
                category: .textile,
                imageURL: "https://commons.wikimedia.org/wiki/Special:Redirect/file/Nasca._Mantle_%28%22The_Paracas_Textile%22%29%2C_overall.jpg?width=900",
                sourceName: "Brooklyn Museum",
                sourceURL: "https://www.brooklynmuseum.org/opencollection/objects/4826",
                license: "Open access image",
                hook: "A woven field of figures, color, and counting.",
                story: """
                Andean textiles were among the most valued works of the ancient Andes. A mantle like this was not just clothing or covering; it could hold status, memory, ritual, and astonishing technical knowledge. The repeated figures and borders invite the eye to move slowly, noticing how color and rhythm are built from thousands of small choices. Before writing systems became common in many parts of the region, textiles carried information through pattern, material, and form. They were portable, intimate, and durable enough to hold a life close. The warmth of the cloth is matched by the intelligence of its structure.
                """,
                whyItMatters: "It reminds us that textiles can be archives, carrying knowledge through fiber, pattern, and use.",
                latitude: -14.0875,
                longitude: -75.7626,
                weekKey: weekKey
            ),
            CultureItem(
                id: "\(weekKey)-book-of-kells",
                title: "Book of Kells, Chi Rho Page",
                maker: "Monastic scribes and illuminators",
                culture: "Insular Irish",
                country: "Ireland",
                region: "Kells / Iona tradition",
                dateDisplay: "c. 800 CE",
                category: .manuscript,
                imageURL: "https://commons.wikimedia.org/wiki/Special:Redirect/file/KellsFol034rChiRhoMonogram.jpg?width=900",
                sourceName: "Trinity College Dublin",
                sourceURL: "https://digitalcollections.tcd.ie/collections/ks65hc20t",
                license: "Public domain / open access image",
                hook: "Letters turn into architecture, garden, and jewel.",
                story: """
                The Chi Rho page of the Book of Kells begins a sacred text by making language almost overflow its own edges. Letterforms expand into knotwork, spirals, small figures, and color. Reading becomes looking; looking becomes a kind of devotion. The page was made in a world where books required animal skin, prepared pigments, careful copying, and long hours of concentrated labor. Its complexity is not ornamental noise. It asks the reader to slow down before entering the story. In a modern screen culture of quick text, the page feels almost radical: a single opening made worthy of lingering.
                """,
                whyItMatters: "It shows the book as a handmade environment, where text, image, devotion, and labor become inseparable.",
                latitude: 53.3450,
                longitude: -6.2540,
                weekKey: weekKey
            ),
            CultureItem(
                id: "\(weekKey)-waldseemuller-map",
                title: "Waldseemuller World Map",
                maker: "Martin Waldseemuller",
                culture: "German Renaissance",
                country: "Germany",
                region: "Saint-Die-des-Vosges workshop",
                dateDisplay: "1507",
                category: .map,
                imageURL: "https://commons.wikimedia.org/wiki/Special:Redirect/file/Waldseemuller_map_2.jpg?width=900",
                sourceName: "Library of Congress",
                sourceURL: "https://www.loc.gov/item/2003626426/",
                license: "Public domain",
                hook: "A printed world map trying to make room for a newly named America.",
                story: """
                The Waldseemuller map is famous for using the name America, but its lasting interest is more human than that single label. It shows knowledge in motion. Classical geography, sailor reports, printing technology, and speculation all meet on one large sheet. Some parts are precise; others are guesses made with the best tools available. That mix is what makes the map moving. It is not a final answer to the world. It is a snapshot of people updating reality together, line by line, name by name. Maps often look authoritative, but this one reveals the imagination and uncertainty inside authority.
                """,
                whyItMatters: "It captures a turning point in how people pictured the planet, reminding us that maps are arguments as well as images.",
                latitude: 48.2897,
                longitude: 6.9483,
                weekKey: weekKey
            )
        ]
    }

    private static func previousItemsOne(weekKey: String) -> [CultureItem] {
        let items = currentItems(weekKey: weekKey)
        return [
            copy(items[6], id: "\(weekKey)-archive-waldseemuller", title: "Waldseemuller Map Detail"),
            copy(items[2], id: "\(weekKey)-archive-zellige", title: "Zellige Pattern Study"),
            copy(items[0], id: "\(weekKey)-archive-faience", title: "Faience River Animal"),
            copy(items[5], id: "\(weekKey)-archive-kells", title: "Insular Gospel Page")
        ]
    }

    private static func previousItemsTwo(weekKey: String) -> [CultureItem] {
        let items = currentItems(weekKey: weekKey)
        return [
            copy(items[3], id: "\(weekKey)-archive-epidaurus", title: "Theatre of Epidaurus"),
            copy(items[1], id: "\(weekKey)-archive-noh", title: "Hannya Noh Mask"),
            copy(items[4], id: "\(weekKey)-archive-paracas", title: "Paracas Textile Fragment"),
            copy(items[2], id: "\(weekKey)-archive-morocco", title: "Marrakesh Tilework")
        ]
    }

    private static func copy(_ item: CultureItem, id: String, title: String) -> CultureItem {
        CultureItem(
            id: id,
            title: title,
            maker: item.maker,
            culture: item.culture,
            country: item.country,
            region: item.region,
            dateDisplay: item.dateDisplay,
            category: item.category,
            imageURL: item.imageURL,
            sourceName: item.sourceName,
            sourceURL: item.sourceURL,
            license: item.license,
            hook: item.hook,
            story: item.story,
            whyItMatters: item.whyItMatters,
            latitude: item.latitude,
            longitude: item.longitude,
            weekKey: item.weekKey,
            guidedScenes: item.guidedScenes
        )
    }

    private static func blueHippoGuidedScenes() -> [GuidedCultureScene] {
        [
            GuidedCultureScene(
                id: "blue-hippo-full-object",
                title: "A River Animal, Held in the Hand",
                body: "This small hippopotamus was made for a tomb, but its rounded body and vivid blue surface still feel startlingly present.",
                focusX: 0.50,
                focusY: 0.54,
                zoom: 1.0,
                callout: "Blue faience body",
                sceneIndex: 0
            ),
            GuidedCultureScene(
                id: "blue-hippo-marsh-plants",
                title: "A Marsh Painted on Its Back",
                body: "Lotus and river plants turn the animal into a tiny Nile landscape. The decoration suggests water, growth, and renewal.",
                focusX: 0.38,
                focusY: 0.32,
                zoom: 1.72,
                highlightX: 0.36,
                highlightY: 0.30,
                highlightRadius: 0.16,
                callout: "Lotus and marsh plants",
                sceneIndex: 1
            ),
            GuidedCultureScene(
                id: "blue-hippo-face",
                title: "Charm and Danger",
                body: "The face is gentle now, but a real hippopotamus was powerful and dangerous. The object holds both affection and awe.",
                focusX: 0.72,
                focusY: 0.48,
                zoom: 1.9,
                highlightX: 0.73,
                highlightY: 0.48,
                highlightRadius: 0.15,
                callout: "A watchful face",
                sceneIndex: 2
            ),
            GuidedCultureScene(
                id: "blue-hippo-faience",
                title: "Color Made by Fire",
                body: "Egyptian faience was quartz-rich and glassy after firing. Its blue-green surface could carry the feeling of river light.",
                focusX: 0.50,
                focusY: 0.42,
                zoom: 1.38,
                callout: "Glassy blue-green surface",
                sceneIndex: 3
            ),
            GuidedCultureScene(
                id: "blue-hippo-pull-back",
                title: "A Companion for Renewal",
                body: "Pulled back, the whole object becomes a hopeful companion: craft, belief, animal power, and affection in one handmade form.",
                focusX: 0.50,
                focusY: 0.52,
                zoom: 1.0,
                sceneIndex: 4
            )
        ]
    }

    private static func nohMaskGuidedScenes() -> [GuidedCultureScene] {
        [
            GuidedCultureScene(
                id: "noh-mask-introduction",
                title: "A Face for the Stage",
                body: "In Noh theater, a mask is not only a disguise. It is an instrument that comes alive through movement, light, and attention.",
                focusX: 0.50,
                focusY: 0.50,
                zoom: 1.0,
                sceneIndex: 0
            ),
            GuidedCultureScene(
                id: "noh-mask-expression",
                title: "Expression in Small Changes",
                body: "A slight tilt can change the feeling of the fixed face. Raised or lowered, the mask can seem open, wounded, severe, or shadowed.",
                focusX: 0.50,
                focusY: 0.42,
                zoom: 1.55,
                callout: "Expression shifts with angle",
                sceneIndex: 1
            ),
            GuidedCultureScene(
                id: "noh-mask-eyes",
                title: "Eyes That Hold Back",
                body: "The eyes do not explain everything. Their restraint lets the performer and audience complete the emotion together.",
                focusX: 0.50,
                focusY: 0.36,
                zoom: 2.15,
                highlightX: 0.50,
                highlightY: 0.36,
                highlightRadius: 0.13,
                callout: "Restrained eyes",
                sceneIndex: 2
            ),
            GuidedCultureScene(
                id: "noh-mask-mouth",
                title: "Ambiguity at the Mouth",
                body: "The mouth can read as pain, anger, or grief depending on how the actor carries the mask through space.",
                focusX: 0.50,
                focusY: 0.58,
                zoom: 2.0,
                highlightX: 0.50,
                highlightY: 0.58,
                highlightRadius: 0.12,
                callout: "Emotional ambiguity",
                sceneIndex: 3
            ),
            GuidedCultureScene(
                id: "noh-mask-handwork",
                title: "Wood, Paint, and Patience",
                body: "The mask's force comes from carved wood, painted surface, and generations of performers learning how little motion is enough.",
                focusX: 0.50,
                focusY: 0.50,
                zoom: 1.32,
                sceneIndex: 4
            ),
            GuidedCultureScene(
                id: "noh-mask-pull-back",
                title: "Still Human, Still Alive",
                body: "Seen whole again, the mask feels alive because it leaves room for gesture, breath, and imagination.",
                focusX: 0.50,
                focusY: 0.50,
                zoom: 1.0,
                sceneIndex: 5
            )
        ]
    }
}
