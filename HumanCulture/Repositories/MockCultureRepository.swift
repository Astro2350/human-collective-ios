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
                subtitle: "Seven quiet works made by hands, memory, and place.",
                items: currentItems
            ),
            makePack(
                weekOffset: -1,
                title: "Tools for Seeing",
                subtitle: "Maps, vessels, and surfaces that helped people make sense of the world.",
                items: previousItemsOne
            ),
            makePack(
                weekOffset: -2,
                title: "Ceremony and Everyday Beauty",
                subtitle: "Objects that made public life, ritual, and daily rooms more meaningful.",
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
                imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/9/96/Standing_Hippopotamus_MET_DP248993.jpg/800px-Standing_Hippopotamus_MET_DP248993.jpg",
                sourceName: "The Metropolitan Museum of Art",
                sourceURL: "https://www.metmuseum.org/art/collection/search/544227",
                license: "Public domain / Met Open Access",
                hook: "A river creature, glazed in blue, carries a whole landscape on its back.",
                story: """
                This small hippopotamus was made for a tomb, but it feels startlingly alive: bright blue, rounded, and patterned with lotus plants that place it back in the Nile marshes. Ancient Egyptian faience was not clay in the usual sense; it was a quartz-rich material that could glow with glassy color after firing. The animal was powerful and dangerous in life, yet here it becomes a companion for renewal. Its painted plants make the body feel like water, reeds, and sunlight compressed into one object. The charm is immediate, but the idea underneath is serious: the world of the living could be carried carefully into the next one.
                """,
                whyItMatters: "It turns a feared animal into a hopeful object, showing how craft, belief, and affection can meet in a single handmade form.",
                latitude: 27.4400,
                longitude: 30.8300,
                weekKey: weekKey
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
                imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/Noh_Mask_Hannya_type.jpg/800px-Noh_Mask_Hannya_type.jpg",
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
                weekKey: weekKey
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
                imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/35/%D9%86%D8%B8%D8%B1%D8%A9_%D9%85%D9%82%D8%B1%D8%A8%D8%A9_%D9%84%D9%84%D8%B2%D9%84%D9%8A%D8%AC_%D9%81%D9%8A_%D9%85%D8%AF%D8%B1%D8%B3%D8%A9_%D8%A7%D8%A8%D9%86_%D9%8A%D9%88%D8%B3%D9%81.jpeg/800px-%D9%86%D8%B8%D8%B1%D8%A9_%D9%85%D9%82%D8%B1%D8%A8%D8%A9_%D9%84%D9%84%D8%B2%D9%84%D9%8A%D8%AC_%D9%81%D9%8A_%D9%85%D8%AF%D8%B1%D8%B3%D8%A9_%D8%A7%D8%A8%D9%86_%D9%8A%D9%88%D8%B3%D9%81.jpeg",
                sourceName: "Wikimedia Commons",
                sourceURL: "https://commons.wikimedia.org/wiki/File:%D9%86%D8%B8%D8%B1%D8%A9_%D9%85%D9%82%D8%B1%D8%A8%D8%A9_%D9%84%D9%84%D8%B2%D9%84%D9%8A%D8%AC_%D9%81%D9%8A_%D9%85%D8%AF%D8%B1%D8%B3%D8%A9_%D8%A7%D8%A8%D9%86_%D9%8A%D9%88%D8%B3%D9%81.jpeg",
                license: "Open access image",
                hook: "Thousands of small cut tiles settle into a calm geometric order.",
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
                imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5b/The_great_theater_of_Epidaurus%2C_designed_by_Polykleitos_the_Younger_in_the_4th_century_BC%2C_Sanctuary_of_Asklepeios_at_Epidaurus%2C_Greece_%2814015010416%29.jpg/800px-The_great_theater_of_Epidaurus%2C_designed_by_Polykleitos_the_Younger_in_the_4th_century_BC%2C_Sanctuary_of_Asklepeios_at_Epidaurus%2C_Greece_%2814015010416%29.jpg",
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
                imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6c/Nasca._Mantle_%28%22The_Paracas_Textile%22%29%2C_overall.jpg/800px-Nasca._Mantle_%28%22The_Paracas_Textile%22%29%2C_overall.jpg",
                sourceName: "Brooklyn Museum",
                sourceURL: "https://www.brooklynmuseum.org/opencollection/objects/4826",
                license: "Open access image",
                hook: "A woven field of figures, color, and counted decisions.",
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
                imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/ee/KellsFol034rChiRhoMonogram.jpg/800px-KellsFol034rChiRhoMonogram.jpg",
                sourceName: "Trinity College Dublin",
                sourceURL: "https://digitalcollections.tcd.ie/collections/ks65hc20t",
                license: "Public domain / open access image",
                hook: "A page where letters become architecture, garden, and jewel.",
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
                imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/Waldseemuller_map_2.jpg/1000px-Waldseemuller_map_2.jpg",
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
            weekKey: item.weekKey
        )
    }
}
