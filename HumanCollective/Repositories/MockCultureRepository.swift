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
                title: "Daily Human Collective",
                subtitle: "Seven daily pieces: animals, maps, faces, games, and ancient craft.",
                items: currentItems
            ),
            makePack(
                weekOffset: -1,
                title: "Creature Features",
                subtitle: "Dogs, cats, horses, octopus forms, a rhinoceros, and one famous stone.",
                items: previousItemsOne
            ),
            makePack(
                weekOffset: -2,
                title: "Tiny Legends",
                subtitle: "Small vessels, famous images, gold, instruments, and handmade pages.",
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
            faienceHippopotamus(weekKey: weekKey),
            hannyaMask(weekKey: weekKey),
            waldseemullerMap(weekKey: weekKey),
            puppiesNetsuke(weekKey: weekKey),
            lewisChessmen(weekKey: weekKey),
            terracottaWarriors(weekKey: weekKey),
            mochePortraitVessel(weekKey: weekKey)
        ]
    }

    private static func previousItemsOne(weekKey: String) -> [CultureItem] {
        [
            colimaDog(weekKey: weekKey),
            bastetCat(weekKey: weekKey),
            octopusJar(weekKey: weekKey),
            haniwaHorse(weekKey: weekKey),
            durerRhinoceros(weekKey: weekKey),
            minoanOctopusVase(weekKey: weekKey),
            rosettaStone(weekKey: weekKey)
        ]
    }

    private static func previousItemsTwo(weekKey: String) -> [CultureItem] {
        [
            turtleVessel(weekKey: weekKey),
            bullRhyton(weekKey: weekKey),
            greatWave(weekKey: weekKey),
            bookOfKells(weekKey: weekKey),
            mocheHeadVessel(weekKey: weekKey),
            maskOfAgamemnon(weekKey: weekKey),
            persianAstrolabe(weekKey: weekKey)
        ]
    }

    private static func faienceHippopotamus(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-faience-hippopotamus",
            title: "Blue Faience Hippopotamus",
            maker: nil,
            culture: "Ancient Egyptian",
            country: "Egypt",
            region: "Middle Kingdom",
            dateDisplay: "c. 1961-1878 BCE",
            category: .artifact,
            imageURL: "https://images.metmuseum.org/CRDImages/eg/original/DP248993.jpg",
            sourceName: "The Metropolitan Museum of Art",
            sourceURL: "https://www.metmuseum.org/art/collection/search/544227",
            license: "Public domain / Met Open Access",
            hook: "A blue river animal with a marsh painted on its back.",
            story: """
            This small hippopotamus was made for a tomb, but it feels startlingly alive: bright blue, rounded, and patterned with lotus plants that place it back in the Nile marshes. Egyptian faience was a quartz-rich material that could glow with glassy color after firing, so the object still has the shine of water and sunlight. Hippos were dangerous animals in life, yet this one becomes oddly lovable because its body is compact, smiling, and carefully painted. The plants on its back make the animal feel like a tiny landscape, not just a figure. Its cuteness is part of the power: it makes a serious idea about rebirth feel close and touchable.
            """,
            whyItMatters: "It turns a feared animal into a hopeful companion, showing how belief, charm, and craft can meet in one small object.",
            latitude: 27.4400,
            longitude: 30.8300,
            weekKey: weekKey
        )
    }

    private static func hannyaMask(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-noh-hannya-mask",
            title: "Hannya Noh Mask",
            maker: nil,
            culture: "Japanese",
            country: "Japan",
            region: "Edo period",
            dateDisplay: "17th-18th century",
            category: .mask,
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/Noh_Mask_Hannya_type.jpg/960px-Noh_Mask_Hannya_type.jpg",
            sourceName: "Wikimedia Commons",
            sourceURL: "https://commons.wikimedia.org/wiki/File:Noh_Mask_Hannya_type.jpg",
            license: "Open access image",
            hook: "A face that changes with the angle of the light.",
            story: """
            In Noh theater, a mask is not just something an actor wears; it is an instrument for controlling emotion. The hannya type can look furious, wounded, eerie, or almost sorrowful depending on how the performer tilts the face. That is what makes it so good in the app: the object is instantly dramatic, but the drama is built from restraint. A fixed carved face becomes alive through tiny movements, stage light, and the viewer's attention. It is spooky and beautiful at the same time, which gives it more personality than a straightforward portrait.
            """,
            whyItMatters: "It shows how an object can hold a performance inside it, waiting for gesture and light to unlock different moods.",
            latitude: 35.6764,
            longitude: 139.6500,
            weekKey: weekKey
        )
    }

    private static func waldseemullerMap(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-waldseemuller-map",
            title: "Waldseemuller World Map",
            maker: "Martin Waldseemuller",
            culture: "German Renaissance",
            country: "Germany",
            region: "Saint-Die-des-Vosges workshop",
            dateDisplay: "1507",
            category: .map,
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/Waldseemuller_map_2.jpg/960px-Waldseemuller_map_2.jpg",
            sourceName: "Library of Congress",
            sourceURL: "https://www.loc.gov/item/2003626426/",
            license: "Public domain",
            hook: "A printed world map trying to make room for a newly named America.",
            story: """
            The Waldseemuller map is famous because it includes the name America, but the cooler part is that it shows a whole worldview mid-update. Classical geography, sailor reports, print technology, and guesses all meet on one huge sheet. Some parts are confident; other parts are speculation wearing the visual language of certainty. That tension makes the map feel alive, not dusty. It is a snapshot of people trying to redraw reality together before anyone had a complete picture.
            """,
            whyItMatters: "It captures a turning point in how people pictured the planet, reminding us that maps are arguments as well as images.",
            latitude: 48.2897,
            longitude: 6.9483,
            weekKey: weekKey
        )
    }

    private static func puppiesNetsuke(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-puppies-netsuke",
            title: "Netsuke of Puppies at Play",
            maker: nil,
            culture: "Japanese",
            country: "Japan",
            region: "Meiji period",
            dateDisplay: "late 19th century",
            category: .object,
            imageURL: "https://images.metmuseum.org/CRDImages/as/original/91_1_968_O1_sf.jpg",
            sourceName: "The Metropolitan Museum of Art",
            sourceURL: "https://www.metmuseum.org/art/collection/search/59681",
            license: "Public domain / Met Open Access",
            hook: "Tiny carved puppies packed into one pocket-sized knot of energy.",
            story: """
            Netsuke were small toggles used with traditional Japanese dress, but many became miniature worlds in their own right. This one works because the subject is so immediate: puppies tumbling together, all movement and softness despite the hard material. At only about an inch high, it rewards the kind of close looking that feels almost private. The artist had to compress paws, heads, and bodies into a form that could sit comfortably in the hand. It is cute, but not shallow; it proves that technical skill can be playful without losing seriousness.
            """,
            whyItMatters: "It makes everyday design feel personal, turning a functional accessory into a small scene of affection and motion.",
            latitude: 35.6764,
            longitude: 139.6500,
            weekKey: weekKey
        )
    }

    private static func lewisChessmen(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-lewis-chessmen",
            title: "Lewis Chessmen",
            maker: nil,
            culture: "Norse / Scottish",
            country: "Scotland",
            region: "Isle of Lewis",
            dateDisplay: "12th century",
            category: .object,
            imageURL: "https://commons.wikimedia.org/wiki/Special:Redirect/file/Lewis_chessmen.jpg?width=900",
            sourceName: "British Museum",
            sourceURL: "https://www.britishmuseum.org/collection/object/H_1831-1101-84",
            license: "Open access image; verify file license before production import",
            hook: "Medieval game pieces with worried little faces.",
            story: """
            The Lewis Chessmen are memorable because they make strategy look human. Queens hold their cheeks, kings sit stiffly, and warriors bite their shields with a seriousness that now feels strangely charming. They were carved from walrus ivory and found on the Isle of Lewis, part of a wider medieval world of trade, games, and courtly display. What could have been plain game equipment becomes a tiny cast of characters. Their appeal is immediate: you can understand rank, anxiety, humor, and personality before reading a single label.
            """,
            whyItMatters: "They show play as a carrier of politics, trade, humor, and imagination across medieval Europe.",
            latitude: 58.2130,
            longitude: -6.3880,
            weekKey: weekKey
        )
    }

    private static func terracottaWarriors(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-terracotta-warriors",
            title: "Terracotta Warriors",
            maker: "Imperial Qin workshops",
            culture: "Chinese",
            country: "China",
            region: "Shaanxi",
            dateDisplay: "c. 210 BCE",
            category: .sculpture,
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/59/Terracotta_warriors.jpg/1280px-Terracotta_warriors.jpg",
            sourceName: "Wikimedia Commons",
            sourceURL: "https://commons.wikimedia.org/wiki/File:Terracotta_warriors.jpg",
            license: "Open access image; verify file license before production import",
            hook: "An army made from earth, rank, repetition, and individual faces.",
            story: """
            The Terracotta Warriors were made for the tomb of Qin Shi Huang, but they do not feel like anonymous background decoration. Their power comes from scale and variation working together: rows of bodies repeat, while faces, armor, hair, and posture keep pulling attention back to individuals. Clay becomes military order, political theater, and a kind of afterlife infrastructure. The cool part is that the figures are massive as a group, but the details still reward close looking. They make empire visible through thousands of crafted human forms.
            """,
            whyItMatters: "It shows state power through craft, repetition, and individuality rather than size alone.",
            latitude: 34.3853,
            longitude: 109.2732,
            weekKey: weekKey
        )
    }

    private static func mochePortraitVessel(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-moche-portrait-vessel",
            title: "Moche Portrait Vessel",
            maker: "Unknown Moche artist",
            culture: "Moche",
            country: "Peru",
            region: "North Coast",
            dateDisplay: "100 BCE-500 CE",
            category: .pottery,
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Portrait_Vessel_of_a_Ruler%2C_100_BC_-_500_AD%2C_Moche%2C_north_coast_of_Peru%2C_ceramic_and_pigment_-_Art_Institute_of_Chicago_-_DSC00321.JPG/960px-Portrait_Vessel_of_a_Ruler%2C_100_BC_-_500_AD%2C_Moche%2C_north_coast_of_Peru%2C_ceramic_and_pigment_-_Art_Institute_of_Chicago_-_DSC00321.JPG",
            sourceName: "Wikimedia Commons",
            sourceURL: "https://commons.wikimedia.org/wiki/File:Portrait_Vessel_of_a_Ruler,_100_BC_-_500_AD,_Moche,_north_coast_of_Peru,_ceramic_and_pigment_-_Art_Institute_of_Chicago_-_DSC00321.JPG",
            license: "Open access image; verify file license before production import",
            hook: "A vessel that treats the human face as a place worth studying.",
            story: """
            Moche portrait vessels make looking at a face feel like the main event. The object is a container, but it is also a likeness shaped around cheeks, brow, mouth, and bearing. That combination makes it feel different from a flat portrait: the person becomes volume, surface, and use all at once. These vessels show how carefully Moche artists observed human presence, status, and expression. It belongs in a daily slot because it is instantly readable, but the longer you sit with it, the stranger and more impressive the format becomes.
            """,
            whyItMatters: "It shows portraiture outside the frame, shaped into something held and used.",
            latitude: -8.1116,
            longitude: -79.0288,
            weekKey: weekKey
        )
    }

    private static func colimaDog(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-colima-seated-dog",
            title: "Colima Seated Dog",
            maker: "Colima artist(s)",
            culture: "Colima",
            country: "Mexico",
            region: "West Mexico",
            dateDisplay: "200 BCE-300 CE",
            category: .sculpture,
            imageURL: "https://images.metmuseum.org/CRDImages/ao/original/75B_18BR2.jpg",
            sourceName: "The Metropolitan Museum of Art",
            sourceURL: "https://www.metmuseum.org/art/collection/search/318964",
            license: "Public domain / Met Open Access",
            hook: "A ceramic dog with the calm confidence of a household celebrity.",
            story: """
            West Mexican Colima artists made ceramic dogs with enough personality to feel almost contemporary. This seated dog has a long body, alert posture, and direct presence, so it reads less like an abstract symbol and more like an animal someone knew well. Dogs appear often in archaeological contexts from the region, and the Met connects this form to the Mexican hairless dog, or xoloitzcuintle. The object is funny and dignified at once. It belongs in the app because it gives ancient art an immediate emotional doorway: people recognize the attitude before they know the history.
            """,
            whyItMatters: "It shows how ancient artists could make animal forms feel familiar, specific, and full of character.",
            latitude: 19.2452,
            longitude: -103.7241,
            weekKey: weekKey
        )
    }

    private static func bastetCat(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-bastet-cat",
            title: "Cat with Image of Bastet",
            maker: nil,
            culture: "Ancient Egyptian",
            country: "Egypt",
            region: "Late Period-Ptolemaic Period",
            dateDisplay: "664-30 BCE",
            category: .artifact,
            imageURL: "https://images.metmuseum.org/CRDImages/eg/original/LC-04_2_471_EGDP031182.jpg",
            sourceName: "The Metropolitan Museum of Art",
            sourceURL: "https://www.metmuseum.org/art/collection/search/570719",
            license: "Public domain / Met Open Access",
            hook: "A poised bronze cat with a goddess carried on its chest.",
            story: """
            This cat is small, alert, and unusually magnetic. The Met identifies it with Bastet, the Egyptian goddess associated with cats, protection, and prosperity. The animal sits with its tail wrapped close, looking calm but watchful, which gives it the exact mix of cute and powerful that works well for this app. It is not just a pet portrait; it is a devotional object shaped through an animal people already understood as graceful and protective. The detail on the chest adds another layer, making the cat a carrier of divine presence.
            """,
            whyItMatters: "It shows how an animal image can be affectionate, sacred, and protective all at once.",
            latitude: 30.9686,
            longitude: 31.1000,
            weekKey: weekKey
        )
    }

    private static func octopusJar(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-octopus-stirrup-jar",
            title: "Terracotta Stirrup Jar with Octopus",
            maker: nil,
            culture: "Helladic, Mycenaean",
            country: "Greece",
            region: "Late Helladic IIIC",
            dateDisplay: "c. 1200-1100 BCE",
            category: .pottery,
            imageURL: "https://images.metmuseum.org/CRDImages/gr/original/DP260421.jpg",
            sourceName: "The Metropolitan Museum of Art",
            sourceURL: "https://www.metmuseum.org/art/collection/search/254779",
            license: "Public domain / Met Open Access",
            hook: "An octopus wraps around the jar like it owns the whole object.",
            story: """
            The octopus is not just painted on the jar; it takes over the jar's round body. Its arms spread across the surface, turning a container into a little underwater world. The Met notes that marine motifs moved through Minoan-inspired Mycenaean pottery, and this piece keeps that sea-life energy while becoming more symmetrical and abstract. That balance is what makes it cool: animal, pattern, and vessel all lock together. You can understand the design instantly, then keep noticing how perfectly it fits the shape.
            """,
            whyItMatters: "It shows decoration becoming structure, with the animal image fitted exactly to the object that carries it.",
            latitude: 37.7308,
            longitude: 22.7561,
            weekKey: weekKey
        )
    }

    private static func haniwaHorse(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-haniwa-horse-head",
            title: "Haniwa Horse's Head",
            maker: nil,
            culture: "Japanese",
            country: "Japan",
            region: "Kofun period",
            dateDisplay: "6th century",
            category: .sculpture,
            imageURL: "https://images.metmuseum.org/CRDImages/as/original/69_249_192144.jpg",
            sourceName: "The Metropolitan Museum of Art",
            sourceURL: "https://www.metmuseum.org/art/collection/search/44442",
            license: "Public domain / Met Open Access",
            hook: "A clay horse head with simple shapes and a huge amount of charm.",
            story: """
            Haniwa were earthenware figures associated with Japanese burial mounds, and animal forms were part of that world. This horse head is fragmentary, but that actually helps it feel more direct: ears, muzzle, and harness details carry the whole personality. It has the freshness of something quickly understood, almost like a character design made from clay. The surface is plain compared with shinier objects, but the silhouette does the work. It adds a different kind of cuteness to the week: quiet, ancient, and a little awkward in the best way.
            """,
            whyItMatters: "It shows how a few clay forms can preserve personality, ceremony, and animal presence across centuries.",
            latitude: 34.6851,
            longitude: 135.8048,
            weekKey: weekKey
        )
    }

    private static func durerRhinoceros(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-durer-rhinoceros",
            title: "Durer's Rhinoceros",
            maker: "Albrecht Durer",
            culture: "German Renaissance",
            country: "Germany",
            region: "Nuremberg",
            dateDisplay: "1515",
            category: .painting,
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/The_Rhinoceros_%28NGA_1964.8.697%29_enhanced.png/960px-The_Rhinoceros_%28NGA_1964.8.697%29_enhanced.png",
            sourceName: "National Gallery of Art",
            sourceURL: "https://www.nga.gov/artworks/47903-rhinoceros",
            license: "Public domain artwork; verify image file license before production import",
            hook: "A rhinoceros drawn like a tiny armored tank by someone who never saw it.",
            story: """
            Durer's rhinoceros is one of the best examples of an image being wrong and unforgettable at the same time. The artist based it on reports and sketches rather than direct observation, so the animal becomes a mix of fact, rumor, armor, scales, and imagination. That is exactly why it is fun to look at. It feels like a creature from a game before games existed, with plates and textures that make it more fantastic than realistic. For centuries, this print helped shape how Europeans pictured a rhinoceros, proving that a compelling image can become its own kind of truth.
            """,
            whyItMatters: "It reminds us that images can shape belief even when they are partly invented.",
            latitude: 49.4521,
            longitude: 11.0767,
            weekKey: weekKey
        )
    }

    private static func minoanOctopusVase(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-minoan-octopus-vase",
            title: "Minoan Octopus Vase",
            maker: nil,
            culture: "Minoan",
            country: "Greece",
            region: "Crete",
            dateDisplay: "c. 1500 BCE",
            category: .pottery,
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/b/bb/Minoan_vase_with_octopus_motif_-_DPLA_-_07d764d5ed7063fed136ae3969ef190d.jpg",
            sourceName: "Wikimedia Commons",
            sourceURL: "https://commons.wikimedia.org/wiki/File:Minoan_vase_with_octopus_motif_-_DPLA_-_07d764d5ed7063fed136ae3969ef190d.jpg",
            license: "Open access image; verify file license before production import",
            hook: "A sea creature wraps itself around a vessel made for human hands.",
            story: """
            This octopus does not sit politely inside a border. It stretches around the vase, using the round surface like water and making the vessel feel alive. The design works because animal, pattern, and object shape are all solving the same visual problem. Arms become movement, the body becomes a center, and the pot becomes an underwater space. It is one of those objects that feels modern because the decoration understands the form so completely.
            """,
            whyItMatters: "It shows decoration becoming structure, fitted exactly to the object that carries it.",
            latitude: 35.2401,
            longitude: 24.8093,
            weekKey: weekKey
        )
    }

    private static func rosettaStone(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-rosetta-stone",
            title: "Rosetta Stone",
            maker: nil,
            culture: "Ptolemaic Egyptian",
            country: "Egypt",
            region: "Rashid / Rosetta",
            dateDisplay: "196 BCE",
            category: .artifact,
            imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/Rosetta_Stone.JPG/960px-Rosetta_Stone.JPG",
            sourceName: "Wikimedia Commons",
            sourceURL: "https://commons.wikimedia.org/wiki/File:Rosetta_Stone.JPG",
            license: "Open access image; verify file license before production import",
            hook: "A broken slab that helped reopen an ancient writing system.",
            story: """
            The Rosetta Stone matters because the same decree appears in three scripts, including Greek and Egyptian hieroglyphs. That repetition gave scholars a way to compare signs, sounds, and meanings across writing systems. The object is not flashy in the usual sense, but its plainness is part of the power: a damaged administrative text became one of the most important translation tools in history. It turns a chunk of stone into a hinge between lost knowledge and readable language.
            """,
            whyItMatters: "It reminds us that understanding often begins with comparison.",
            latitude: 31.4044,
            longitude: 30.4164,
            weekKey: weekKey
        )
    }

    private static func turtleVessel(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-colima-turtle-vessel",
            title: "Colima Turtle Vessel",
            maker: "Colima artist(s)",
            culture: "Colima",
            country: "Mexico",
            region: "Mesoamerica",
            dateDisplay: "200 BCE-300 CE",
            category: .pottery,
            imageURL: "https://images.metmuseum.org/CRDImages/ao/original/DP-23901-002.jpg",
            sourceName: "The Metropolitan Museum of Art",
            sourceURL: "https://www.metmuseum.org/art/collection/search/319065",
            license: "Public domain / Met Open Access",
            hook: "A turtle-shaped vessel that looks like it just paused mid-waddle.",
            story: """
            This Colima vessel is practical and charming at the same time. The turtle's rounded legs support the form, while the body becomes a container with animal presence. The Met describes the figure as modeled upright, suggesting the turtle in the act of basking or grazing. That small behavioral detail makes the object feel observed rather than generic. It is a good example of why cute objects can still be culturally rich: the humor comes from close attention to the living world.
            """,
            whyItMatters: "It shows how a useful vessel can become an animal study, carrying function and affection in the same shape.",
            latitude: 19.2452,
            longitude: -103.7241,
            weekKey: weekKey
        )
    }

    private static func bullRhyton(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-minoan-bull-rhyton",
            title: "Minoan Bull's-Head Rhyton",
            maker: nil,
            culture: "Minoan",
            country: "Greece",
            region: "Crete",
            dateDisplay: "c. 1450-1400 BCE",
            category: .pottery,
            imageURL: "https://images.metmuseum.org/CRDImages/gr/original/DP258537.jpg",
            sourceName: "The Metropolitan Museum of Art",
            sourceURL: "https://www.metmuseum.org/art/collection/search/255506",
            license: "Public domain / Met Open Access",
            hook: "A little bull head made to pour ritual liquid from its muzzle.",
            story: """
            This vessel is shaped as a bull's head, which already gives it a strong first impression. The Met identifies it as a rhyton, a type of libation vessel, where liquid could be poured through the animal's muzzle. That makes the design more than decoration: the animal form explains how the object worked. Bulls mattered deeply in Minoan visual culture, and this small terracotta version makes that power handheld. It feels playful now, but its original use would have connected animal force, ritual action, and craft.
            """,
            whyItMatters: "It shows how ritual objects could make function, animal symbolism, and performance happen in one form.",
            latitude: 35.2401,
            longitude: 24.8093,
            weekKey: weekKey
        )
    }

    private static func greatWave(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-great-wave",
            title: "The Great Wave off Kanagawa",
            maker: "Katsushika Hokusai",
            culture: "Japanese",
            country: "Japan",
            region: "Edo period",
            dateDisplay: "c. 1830-1832",
            category: .painting,
            imageURL: "https://images.metmuseum.org/CRDImages/as/original/DP141042.jpg",
            sourceName: "The Metropolitan Museum of Art",
            sourceURL: "https://www.metmuseum.org/art/collection/search/39799",
            license: "Public domain / Met Open Access",
            hook: "A wave that looks like claws, snow, and a mountain all at once.",
            story: """
            Hokusai's Great Wave is famous for a reason: it is easy to recognize and still strange after hundreds of views. The wave rises like a creature, the boats dip under it, and Mount Fuji sits tiny and still in the distance. The print is not large, but the design makes the moment feel enormous. It belongs in this curation because it delivers instant visual impact while still rewarding slower looking. The foam, curve, and scale all work together to make nature feel both beautiful and dangerous.
            """,
            whyItMatters: "It shows how a printed image can become global without losing the force of its original design.",
            latitude: 35.3606,
            longitude: 138.7274,
            weekKey: weekKey
        )
    }

    private static func bookOfKells(weekKey: String) -> CultureItem {
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
            hook: "A page where letters turn into knots, creatures, and jewels.",
            story: """
            The Chi Rho page of the Book of Kells makes text feel like a living surface. Letterforms expand into knotwork, spirals, figures, and color until reading becomes a form of looking. The page was made in a world where books required prepared skins, pigments, copying, and long stretches of disciplined labor. Its complexity is not random decoration; it slows the viewer down before the sacred story continues. In a screen culture of quick text, the page feels almost radical because it asks one opening to be worth lingering over.
            """,
            whyItMatters: "It shows the book as a handmade environment where text, image, devotion, and labor become inseparable.",
            latitude: 53.3450,
            longitude: -6.2540,
            weekKey: weekKey
        )
    }

    private static func mocheHeadVessel(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-moche-head-vessel",
            title: "Moche Head Vessel",
            maker: nil,
            culture: "Moche",
            country: "Peru",
            region: "North Coast",
            dateDisplay: "2nd-6th century",
            category: .pottery,
            imageURL: "https://images.metmuseum.org/CRDImages/ao/original/vs1978_412_72.jpg",
            sourceName: "The Metropolitan Museum of Art",
            sourceURL: "https://www.metmuseum.org/art/collection/search/310524",
            license: "Public domain / Met Open Access",
            hook: "A small vessel that stares back like a portrait.",
            story: """
            Moche artists made ceramic vessels that treat faces as serious subjects. This head vessel is compact, but it gives attention to the brow, lips, and expression in a way that feels direct. The object is not a flat portrait; it is a container shaped around a human presence. That makes it weird in the right way for the app: useful form and likeness are fused together. It helps show that ancient art can be personal, observant, and a little uncanny without needing a huge monument.
            """,
            whyItMatters: "It shows portraiture outside the frame, shaped into an object that could be held, carried, and used.",
            latitude: -8.1116,
            longitude: -79.0288,
            weekKey: weekKey
        )
    }

    private static func maskOfAgamemnon(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-mask-of-agamemnon",
            title: "Gold Funerary Mask",
            maker: nil,
            culture: "Mycenaean",
            country: "Greece",
            region: "Mycenae",
            dateDisplay: "16th century BCE",
            category: .jewelry,
            imageURL: "https://commons.wikimedia.org/wiki/Special:Redirect/file/Agamemnon_mask_NAMA_Athens_Greece.jpg?width=900",
            sourceName: "Wikimedia Commons",
            sourceURL: "https://commons.wikimedia.org/wiki/File:Agamemnon_mask_NAMA_Athens_Greece.jpg",
            license: "Open access image; verify file license before production import",
            hook: "A sheet of gold pressed into the memory of a face.",
            story: """
            This gold funerary mask is famous partly because of its dramatic modern nickname, but the stronger point is simpler: burial becomes presence. A thin sheet of precious metal is shaped into eyes, nose, mouth, beard, and expression, making a face endure after the body is hidden. The mask asks viewers to think about memory as material. Gold is not only valuable here; it is a way to make mourning visible, durable, and difficult to ignore.
            """,
            whyItMatters: "It shows how precious materials can make mourning and memory visible.",
            latitude: 37.7308,
            longitude: 22.7561,
            weekKey: weekKey
        )
    }

    private static func persianAstrolabe(weekKey: String) -> CultureItem {
        CultureItem(
            id: "\(weekKey)-persian-astrolabe",
            title: "Persian Astrolabe",
            maker: nil,
            culture: "Persian",
            country: "Iran",
            region: nil,
            dateDisplay: "18th century",
            category: .tool,
            imageURL: "https://commons.wikimedia.org/wiki/Special:Redirect/file/Astrolabe-Persian-18C.jpg?width=900",
            sourceName: "Wikimedia Commons",
            sourceURL: "https://commons.wikimedia.org/wiki/File:Astrolabe-Persian-18C.jpg",
            license: "Open access image; verify file license before production import",
            hook: "A handheld model of sky, time, and calculation.",
            story: """
            An astrolabe makes the sky usable. Its engraved circles, plates, and pointer turn observation into a portable tool for time, position, and calculation. What makes this kind of object so good for close looking is that beauty and function are inseparable: the lines are not just decoration, but instructions and measurements. It shows science as something crafted, carried, touched, and read by hand.
            """,
            whyItMatters: "It shows science as something crafted, carried, and touched.",
            latitude: 32.4279,
            longitude: 53.6880,
            weekKey: weekKey
        )
    }
}
