//
//  CommandHierarchy.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Represents a category of Traktor commands for hierarchical menu display.
struct CommandCategory2: Identifiable {
    let id = UUID()
    let name: String
    let subcategories: [CommandCategory2]?
    let commands: [CommandItem]?

    init(name: String, subcategories: [CommandCategory2]? = nil, commands: [CommandItem]? = nil) {
        self.name = name
        self.subcategories = subcategories
        self.commands = commands
    }
}

/// An ID-only hierarchy item resolved through the authoritative catalog.
struct CommandItem: Identifiable {
    let descriptor: TraktorCommandDescriptor

    var id: Int { descriptor.id }
    var name: String { descriptor.name }
    var verification: TraktorCommandDescriptor.Verification { descriptor.verification }
    var supportedDirections: Set<IODirection> { descriptor.supportedDirections }

    init(id: Int) {
        descriptor = TraktorCommands.descriptor(for: id)
    }
}

/// Hierarchical organization of Traktor commands for menu display.
enum CommandHierarchy {

    static func flatten(_ categories: [CommandCategory2]) -> [TraktorCommandDescriptor] {
        categories.flatMap { category in
            let nested = category.subcategories.map(flatten) ?? []
            let direct = category.commands?.map(\.descriptor) ?? []
            return nested + direct
        }
    }

    static func verifiedCategories(for direction: IODirection) -> [CommandCategory2] {
        categories.compactMap { verifiedCategory($0, for: direction) }
    }

    private static func verifiedCategory(
        _ category: CommandCategory2,
        for direction: IODirection
    ) -> CommandCategory2? {
        let subcategories = category.subcategories?.compactMap {
            verifiedCategory($0, for: direction)
        }
        let commands = category.commands?.filter {
            $0.verification == .verifiedTraktor441 && $0.descriptor.supports(direction)
        }

        let retainedSubcategories = subcategories?.isEmpty == false ? subcategories : nil
        let retainedCommands = commands?.isEmpty == false ? commands : nil
        guard retainedSubcategories != nil || retainedCommands != nil else {
            return nil
        }

        return CommandCategory2(
            name: category.name,
            subcategories: retainedSubcategories,
            commands: retainedCommands
        )
    }

    /// Returns the full command hierarchy for menus
    static let categories: [CommandCategory2] = [
        // Mixer
        CommandCategory2(name: "Mixer", subcategories: [
            CommandCategory2(name: "Main", commands: [
                CommandItem(id: 5),
                CommandItem(id: 6),
                CommandItem(id: 7),
                CommandItem(id: 8),
                CommandItem(id: 17),
                CommandItem(id: 9),
                CommandItem(id: 14),
                CommandItem(id: 19),
                CommandItem(id: 60),
            ]),
            CommandCategory2(name: "Tempo Master", commands: [
                CommandItem(id: 62),
                CommandItem(id: 64),
                CommandItem(id: 69),
                CommandItem(id: 2471),
                CommandItem(id: 2472),
            ]),
            CommandCategory2(name: "Mixer FX", commands: [
                CommandItem(id: 349),
                CommandItem(id: 350),
                CommandItem(id: 351),
            ]),
            CommandCategory2(name: "Audio Recorder", commands: [
                CommandItem(id: 29),
                CommandItem(id: 2055),
                CommandItem(id: 2056),
                CommandItem(id: 2057),
                CommandItem(id: 2058),
                CommandItem(id: 3084),
            ]),
            CommandCategory2(name: "Output Meters", commands: [
                CommandItem(id: 2704),
                CommandItem(id: 2705),
                CommandItem(id: 2706),
                CommandItem(id: 2707),
                CommandItem(id: 2708),
                CommandItem(id: 2709),
                CommandItem(id: 2710),
            ]),
        ]),

        // Deck Common
        CommandCategory2(name: "Deck Common", subcategories: [
            CommandCategory2(name: "Transport", commands: [
                CommandItem(id: 100),
                CommandItem(id: 101),
                CommandItem(id: 102),
                CommandItem(id: 103),
                CommandItem(id: 104),
                CommandItem(id: 117),
                CommandItem(id: 118),
                CommandItem(id: 119),
                CommandItem(id: 127),
            ]),
            CommandCategory2(name: "Jog", commands: [
                CommandItem(id: 120),
                CommandItem(id: 121),
                CommandItem(id: 2187),
                CommandItem(id: 2188),
            ]),
            CommandCategory2(name: "Tempo", commands: [
                CommandItem(id: 122),
                CommandItem(id: 123),
                CommandItem(id: 124),
                CommandItem(id: 125),
                CommandItem(id: 126),
                CommandItem(id: 404),
                CommandItem(id: 406),
                CommandItem(id: 2292),
                CommandItem(id: 2293),
                CommandItem(id: 2294),
                CommandItem(id: 2476),
                CommandItem(id: 2477),
                CommandItem(id: 512),
            ]),
            CommandCategory2(name: "Key", commands: [
                CommandItem(id: 400),
                CommandItem(id: 401),
                CommandItem(id: 402),
                CommandItem(id: 403),
                CommandItem(id: 405),
                CommandItem(id: 2291),
            ]),
            CommandCategory2(name: "Grid", commands: [
                CommandItem(id: 513),
                CommandItem(id: 2237),
                CommandItem(id: 2238),
                CommandItem(id: 2239),
                CommandItem(id: 2240),
                CommandItem(id: 2241),
                CommandItem(id: 2242),
                CommandItem(id: 2248),
                CommandItem(id: 2249),
                CommandItem(id: 2250),
                CommandItem(id: 2251),
                CommandItem(id: 2252),
                CommandItem(id: 2253),
                CommandItem(id: 2254),
                CommandItem(id: 2255),
                CommandItem(id: 2256),
                CommandItem(id: 2257),
                CommandItem(id: 2258),
                CommandItem(id: 2259),
                CommandItem(id: 2810),
                CommandItem(id: 2811),
            ]),
            CommandCategory2(name: "Load", commands: [
                CommandItem(id: 2176),
                CommandItem(id: 2177),
                CommandItem(id: 2178),
                CommandItem(id: 2180),
                CommandItem(id: 2394),
                CommandItem(id: 2395),
                CommandItem(id: 2401),
                CommandItem(id: 2402),
                CommandItem(id: 2403),
                CommandItem(id: 2404),
            ]),
            CommandCategory2(name: "Status", commands: [
                CommandItem(id: 2295),
                CommandItem(id: 2296),
                CommandItem(id: 2297),
                CommandItem(id: 2303),
                CommandItem(id: 2304),
                CommandItem(id: 2589),
                CommandItem(id: 2590),
                CommandItem(id: 2591),
            ]),
            CommandCategory2(name: "Track Info", commands: [
                CommandItem(id: 2592),
                CommandItem(id: 2593),
                CommandItem(id: 2594),
                CommandItem(id: 2595),
                CommandItem(id: 2596),
                CommandItem(id: 2597),
                CommandItem(id: 2598),
            ]),
            CommandCategory2(name: "Meters", commands: [
                CommandItem(id: 2688),
                CommandItem(id: 2689),
                CommandItem(id: 2690),
                CommandItem(id: 2691),
                CommandItem(id: 2692),
                CommandItem(id: 2693),
                CommandItem(id: 2694),
                CommandItem(id: 2695),
                CommandItem(id: 2696),
                CommandItem(id: 2697),
                CommandItem(id: 2698),
                CommandItem(id: 2699),
                CommandItem(id: 2700),
                CommandItem(id: 2701),
                CommandItem(id: 2702),
                CommandItem(id: 2703),
                CommandItem(id: 2712),
                CommandItem(id: 2713),
            ]),
        ]),

        // Cue & Loop
        CommandCategory2(name: "Cue / Loop", subcategories: [
            CommandCategory2(name: "Cue", commands: [
                CommandItem(id: 206),
                CommandItem(id: 204),
                CommandItem(id: 205),
                CommandItem(id: 207),
                CommandItem(id: 208),
                CommandItem(id: 209),
                CommandItem(id: 213),
                CommandItem(id: 2392),
            ]),
            CommandCategory2(name: "Loop", commands: [
                CommandItem(id: 200),
                CommandItem(id: 201),
                CommandItem(id: 202),
                CommandItem(id: 203),
                CommandItem(id: 2192),
                CommandItem(id: 2193),
                CommandItem(id: 2194),
                CommandItem(id: 2195),
                CommandItem(id: 2196),
                CommandItem(id: 2197),
                CommandItem(id: 2198),
                CommandItem(id: 2316),
                CommandItem(id: 2317),
                CommandItem(id: 2318),
                CommandItem(id: 2319),
                CommandItem(id: 2393),
            ]),
            CommandCategory2(name: "Hotcue", commands: [
                CommandItem(id: 214),
                CommandItem(id: 215),
                CommandItem(id: 216),
                CommandItem(id: 217),
                CommandItem(id: 218),
                CommandItem(id: 219),
                CommandItem(id: 220),
                CommandItem(id: 221),
                CommandItem(id: 2306),
                CommandItem(id: 2307),
                CommandItem(id: 2308),
                CommandItem(id: 2309),
                CommandItem(id: 2310),
                CommandItem(id: 2314),
                CommandItem(id: 2315),
                CommandItem(id: 2327),
                CommandItem(id: 2328),
                CommandItem(id: 2329),
                CommandItem(id: 2330),
                CommandItem(id: 2331),
                CommandItem(id: 2333),
                CommandItem(id: 2334),
                CommandItem(id: 2335),
                CommandItem(id: 2336),
                CommandItem(id: 2337),
                CommandItem(id: 2338),
                CommandItem(id: 2339),
                CommandItem(id: 2340),
            ]),
            CommandCategory2(name: "Move & Beatjump", commands: [
                CommandItem(id: 2351),
                CommandItem(id: 2352),
                CommandItem(id: 2353),
                CommandItem(id: 2372),
                CommandItem(id: 2380),
                CommandItem(id: 2381),
                CommandItem(id: 2382),
                CommandItem(id: 2391),
            ]),
            CommandCategory2(name: "Misc", commands: [
                CommandItem(id: 210),
                CommandItem(id: 211),
                CommandItem(id: 212),
                CommandItem(id: 229),
                CommandItem(id: 230),
                CommandItem(id: 2311),
                CommandItem(id: 2312),
                CommandItem(id: 2313),
                CommandItem(id: 2350),
            ]),
        ]),

        // EQ
        CommandCategory2(name: "EQ", commands: [
            CommandItem(id: 301),
            CommandItem(id: 302),
            CommandItem(id: 303),
            CommandItem(id: 316),
            CommandItem(id: 304),
            CommandItem(id: 305),
            CommandItem(id: 306),
            CommandItem(id: 307),
            CommandItem(id: 308),
            CommandItem(id: 309),
            CommandItem(id: 310),
        ]),

        // Filter
        CommandCategory2(name: "Filter", commands: [
            CommandItem(id: 320),
            CommandItem(id: 319),
        ]),

        // FX
        CommandCategory2(name: "FX", subcategories: [
            CommandCategory2(name: "FX Unit", commands: [
                CommandItem(id: 369),
                CommandItem(id: 365),
                CommandItem(id: 366),
                CommandItem(id: 367),
                CommandItem(id: 368),
                CommandItem(id: 370),
                CommandItem(id: 371),
                CommandItem(id: 372),
                CommandItem(id: 362),
                CommandItem(id: 363),
                CommandItem(id: 364),
                CommandItem(id: 2301),
                CommandItem(id: 324),
                CommandItem(id: 326),
                CommandItem(id: 327),
                CommandItem(id: 373),
                CommandItem(id: 374),
                CommandItem(id: 375),
                CommandItem(id: 323),
            ]),
            CommandCategory2(name: "FX Assign", commands: [
                CommandItem(id: 321),
                CommandItem(id: 322),
                CommandItem(id: 338),
                CommandItem(id: 339),
                CommandItem(id: 348),
                CommandItem(id: 325),
            ]),
            CommandCategory2(name: "FX Meters", commands: [
                CommandItem(id: 2711),
                CommandItem(id: 2714),
            ]),
        ]),

        // Remix Deck
        CommandCategory2(name: "Remix Deck", subcategories: [
            CommandCategory2(name: "Slot Controls", commands: [
                CommandItem(id: 251),
                CommandItem(id: 252),
                CommandItem(id: 249),
                CommandItem(id: 250),
                CommandItem(id: 248),
                CommandItem(id: 269),
                CommandItem(id: 237),
                CommandItem(id: 238),
                CommandItem(id: 239),
                CommandItem(id: 232),
                CommandItem(id: 240),
                CommandItem(id: 259),
                CommandItem(id: 235),
                CommandItem(id: 265),
                CommandItem(id: 253),
                CommandItem(id: 262),
                CommandItem(id: 261),
            ]),
            CommandCategory2(name: "Slot Size", commands: [
                CommandItem(id: 2000),
                CommandItem(id: 2001),
                CommandItem(id: 266),
                CommandItem(id: 267),
                CommandItem(id: 268),
            ]),
            CommandCategory2(name: "Playback", commands: [
                CommandItem(id: 241),
                CommandItem(id: 255),
                CommandItem(id: 256),
                CommandItem(id: 257),
                CommandItem(id: 258),
                CommandItem(id: 260),
                CommandItem(id: 242),
                CommandItem(id: 243),
                CommandItem(id: 254),
            ]),
            CommandCategory2(name: "Load & Capture", commands: [
                CommandItem(id: 233),
                CommandItem(id: 234),
                CommandItem(id: 244),
                CommandItem(id: 245),
                CommandItem(id: 263),
                CommandItem(id: 264),
                CommandItem(id: 246),
                CommandItem(id: 2002),
                CommandItem(id: 2003),
            ]),
            CommandCategory2(name: "Cell Triggers (Slot 1)", commands: [
                CommandItem(id: 601),
                CommandItem(id: 602),
                CommandItem(id: 603),
                CommandItem(id: 604),
                CommandItem(id: 605),
                CommandItem(id: 606),
                CommandItem(id: 607),
                CommandItem(id: 608),
                CommandItem(id: 609),
                CommandItem(id: 610),
                CommandItem(id: 611),
                CommandItem(id: 612),
                CommandItem(id: 613),
                CommandItem(id: 614),
                CommandItem(id: 615),
                CommandItem(id: 616),
            ]),
            CommandCategory2(name: "Cell Triggers (Slot 2)", commands: [
                CommandItem(id: 617),
                CommandItem(id: 618),
                CommandItem(id: 619),
                CommandItem(id: 620),
                CommandItem(id: 621),
                CommandItem(id: 622),
                CommandItem(id: 623),
                CommandItem(id: 624),
                CommandItem(id: 625),
                CommandItem(id: 626),
                CommandItem(id: 627),
                CommandItem(id: 628),
                CommandItem(id: 629),
                CommandItem(id: 630),
                CommandItem(id: 631),
                CommandItem(id: 632),
            ]),
            CommandCategory2(name: "Cell Triggers (Slot 3)", commands: [
                CommandItem(id: 633),
                CommandItem(id: 634),
                CommandItem(id: 635),
                CommandItem(id: 636),
                CommandItem(id: 637),
                CommandItem(id: 638),
                CommandItem(id: 639),
                CommandItem(id: 640),
                CommandItem(id: 641),
                CommandItem(id: 642),
                CommandItem(id: 643),
                CommandItem(id: 644),
                CommandItem(id: 645),
                CommandItem(id: 646),
                CommandItem(id: 647),
                CommandItem(id: 648),
            ]),
            CommandCategory2(name: "Cell Triggers (Slot 4)", commands: [
                CommandItem(id: 649),
                CommandItem(id: 650),
                CommandItem(id: 651),
                CommandItem(id: 652),
                CommandItem(id: 653),
                CommandItem(id: 654),
                CommandItem(id: 655),
                CommandItem(id: 656),
                CommandItem(id: 657),
                CommandItem(id: 658),
                CommandItem(id: 659),
                CommandItem(id: 660),
                CommandItem(id: 661),
                CommandItem(id: 662),
                CommandItem(id: 663),
                CommandItem(id: 664),
            ]),
            CommandCategory2(name: "Cell States (Slot 1)", commands: [
                CommandItem(id: 665),
                CommandItem(id: 666),
                CommandItem(id: 667),
                CommandItem(id: 668),
                CommandItem(id: 669),
                CommandItem(id: 670),
                CommandItem(id: 671),
                CommandItem(id: 672),
                CommandItem(id: 673),
                CommandItem(id: 674),
                CommandItem(id: 675),
                CommandItem(id: 676),
                CommandItem(id: 677),
                CommandItem(id: 678),
                CommandItem(id: 679),
                CommandItem(id: 680),
            ]),
            CommandCategory2(name: "Cell States (Slot 2)", commands: [
                CommandItem(id: 681),
                CommandItem(id: 682),
                CommandItem(id: 683),
                CommandItem(id: 684),
                CommandItem(id: 685),
                CommandItem(id: 686),
                CommandItem(id: 687),
                CommandItem(id: 688),
                CommandItem(id: 689),
                CommandItem(id: 690),
                CommandItem(id: 691),
                CommandItem(id: 692),
                CommandItem(id: 693),
                CommandItem(id: 694),
                CommandItem(id: 695),
                CommandItem(id: 696),
            ]),
            CommandCategory2(name: "Cell States (Slot 3)", commands: [
                CommandItem(id: 697),
                CommandItem(id: 698),
                CommandItem(id: 699),
                CommandItem(id: 700),
                CommandItem(id: 701),
                CommandItem(id: 702),
                CommandItem(id: 703),
                CommandItem(id: 704),
                CommandItem(id: 705),
                CommandItem(id: 706),
                CommandItem(id: 707),
                CommandItem(id: 708),
                CommandItem(id: 709),
                CommandItem(id: 710),
                CommandItem(id: 711),
                CommandItem(id: 712),
            ]),
            CommandCategory2(name: "Cell States (Slot 4)", commands: [
                CommandItem(id: 713),
                CommandItem(id: 714),
                CommandItem(id: 715),
                CommandItem(id: 716),
                CommandItem(id: 717),
                CommandItem(id: 718),
                CommandItem(id: 719),
                CommandItem(id: 720),
                CommandItem(id: 721),
                CommandItem(id: 722),
                CommandItem(id: 723),
                CommandItem(id: 724),
                CommandItem(id: 725),
                CommandItem(id: 726),
                CommandItem(id: 727),
                CommandItem(id: 728),
            ]),
            CommandCategory2(name: "Cell Modifiers", commands: [
                CommandItem(id: 729),
                CommandItem(id: 730),
                CommandItem(id: 731),
                CommandItem(id: 732),
                CommandItem(id: 733),
            ]),
            CommandCategory2(name: "State & Status", commands: [
                CommandItem(id: 247),
                CommandItem(id: 236),
                CommandItem(id: 2004),
                CommandItem(id: 361),
            ]),
        ]),

        // Step Sequencer
        CommandCategory2(name: "Step Sequencer", commands: [
            CommandItem(id: 734),
            CommandItem(id: 735),
            CommandItem(id: 736),
            CommandItem(id: 737),
            CommandItem(id: 738),
            CommandItem(id: 739),
            CommandItem(id: 740),
            CommandItem(id: 741),
            CommandItem(id: 742),
            CommandItem(id: 743),
            CommandItem(id: 744),
            CommandItem(id: 745),
            CommandItem(id: 746),
            CommandItem(id: 747),
            CommandItem(id: 748),
            CommandItem(id: 749),
            CommandItem(id: 750),
            CommandItem(id: 751),
            CommandItem(id: 752),
            CommandItem(id: 753),
            CommandItem(id: 754),
            CommandItem(id: 755),
            CommandItem(id: 756),
        ]),

        // Freeze Mode
        CommandCategory2(name: "Freeze Mode", subcategories: [
            CommandCategory2(name: "Controls", commands: [
                CommandItem(id: 803),
                CommandItem(id: 802),
                CommandItem(id: 804),
            ]),
            CommandCategory2(name: "Slice Triggers", commands: [
                CommandItem(id: 810),
                CommandItem(id: 811),
                CommandItem(id: 812),
                CommandItem(id: 813),
                CommandItem(id: 814),
                CommandItem(id: 815),
                CommandItem(id: 816),
                CommandItem(id: 817),
                CommandItem(id: 818),
                CommandItem(id: 819),
                CommandItem(id: 820),
                CommandItem(id: 821),
                CommandItem(id: 822),
                CommandItem(id: 823),
                CommandItem(id: 824),
                CommandItem(id: 825),
            ]),
        ]),

        // Loop Recorder
        CommandCategory2(name: "Loop Recorder", commands: [
            CommandItem(id: 280),
            CommandItem(id: 281),
            CommandItem(id: 282),
            CommandItem(id: 283),
            CommandItem(id: 284),
            CommandItem(id: 285),
            CommandItem(id: 286),
            CommandItem(id: 287),
        ]),

        // Browser
        CommandCategory2(name: "Browser", subcategories: [
            CommandCategory2(name: "List", commands: [
                CommandItem(id: 3200),
                CommandItem(id: 3201),
                CommandItem(id: 3202),
                CommandItem(id: 3203),
                CommandItem(id: 3204),
                CommandItem(id: 3205),
                CommandItem(id: 3206),
                CommandItem(id: 3207),
                CommandItem(id: 3208),
                CommandItem(id: 3209),
                CommandItem(id: 3210),
            ]),
            CommandCategory2(name: "Actions", commands: [
                CommandItem(id: 3211),
                CommandItem(id: 3212),
                CommandItem(id: 3213),
                CommandItem(id: 3214),
                CommandItem(id: 3215),
                CommandItem(id: 3216),
                CommandItem(id: 3217),
                CommandItem(id: 3218),
                CommandItem(id: 3219),
                CommandItem(id: 3220),
                CommandItem(id: 3223),
                CommandItem(id: 3224),
                CommandItem(id: 3225),
                CommandItem(id: 3231),
                CommandItem(id: 3232),
                CommandItem(id: 3233),
            ]),
            CommandCategory2(name: "Search", commands: [
                CommandItem(id: 3221),
                CommandItem(id: 3222),
                CommandItem(id: 3357),
            ]),
            CommandCategory2(name: "Tree", commands: [
                CommandItem(id: 3328),
                CommandItem(id: 3329),
                CommandItem(id: 3330),
                CommandItem(id: 3336),
                CommandItem(id: 3337),
                CommandItem(id: 3338),
                CommandItem(id: 3339),
                CommandItem(id: 3340),
                CommandItem(id: 3358),
                CommandItem(id: 3366),
                CommandItem(id: 3477),
                CommandItem(id: 3478),
            ]),
            CommandCategory2(name: "Favorites", commands: [
                CommandItem(id: 3456),
                CommandItem(id: 3457),
                CommandItem(id: 3458),
                CommandItem(id: 3459),
                CommandItem(id: 3460),
                CommandItem(id: 3461),
                CommandItem(id: 3462),
                CommandItem(id: 3476),
                CommandItem(id: 3480),
            ]),
            CommandCategory2(name: "Playlists", commands: [
                CommandItem(id: 3345),
                CommandItem(id: 3346),
                CommandItem(id: 3347),
                CommandItem(id: 3348),
                CommandItem(id: 3349),
                CommandItem(id: 3353),
                CommandItem(id: 3354),
                CommandItem(id: 3367),
                CommandItem(id: 3373),
                CommandItem(id: 3374),
                CommandItem(id: 3375),
                CommandItem(id: 3376),
            ]),
            CommandCategory2(name: "Samples", commands: [
                CommandItem(id: 3469),
                CommandItem(id: 3470),
                CommandItem(id: 3471),
                CommandItem(id: 3472),
                CommandItem(id: 3473),
                CommandItem(id: 3474),
                CommandItem(id: 3475),
            ]),
        ]),

        // Global
        CommandCategory2(name: "Global", subcategories: [
            CommandCategory2(name: "Clock", commands: [
                CommandItem(id: 2468),
                CommandItem(id: 2469),
                CommandItem(id: 2470),
                CommandItem(id: 2473),
                CommandItem(id: 2474),
                CommandItem(id: 2475),
            ]),
            CommandCategory2(name: "Deck Assignment", commands: [
                CommandItem(id: 2408),
                CommandItem(id: 2409),
                CommandItem(id: 2410),
                CommandItem(id: 2113),
                CommandItem(id: 2114),
            ]),
            CommandCategory2(name: "View", commands: [
                CommandItem(id: 4162),
                CommandItem(id: 4163),
                CommandItem(id: 4208),
                CommandItem(id: 4209),
                CommandItem(id: 4210),
                CommandItem(id: 4211),
                CommandItem(id: 4212),
                CommandItem(id: 4213),
                CommandItem(id: 4214),
                CommandItem(id: 4215),
                CommandItem(id: 4216),
                CommandItem(id: 2298),
                CommandItem(id: 2299),
                CommandItem(id: 2300),
                CommandItem(id: 2302),
                CommandItem(id: 2305),
                CommandItem(id: 2588),
                CommandItem(id: 2748),
                CommandItem(id: 2807),
                CommandItem(id: 2808),
                CommandItem(id: 2809),
            ]),
            CommandCategory2(name: "Timecode", commands: [
                CommandItem(id: 5129),
                CommandItem(id: 5144),
                CommandItem(id: 5154),
                CommandItem(id: 5155),
                CommandItem(id: 5156),
                CommandItem(id: 2288),
                CommandItem(id: 2289),
                CommandItem(id: 2290),
                CommandItem(id: 3076),
            ]),
            CommandCategory2(name: "System", commands: [
                CommandItem(id: 3072),
                CommandItem(id: 3077),
                CommandItem(id: 3137),
                CommandItem(id: 3138),
                CommandItem(id: 3139),
                CommandItem(id: 3172),
                CommandItem(id: 2179),
                CommandItem(id: 2798),
                CommandItem(id: 3048),
            ]),
            CommandCategory2(name: "Cruise Mode", commands: [
                CommandItem(id: 8194),
                CommandItem(id: 8195),
                CommandItem(id: 8196),
            ]),
        ]),

        // Modifier
        CommandCategory2(name: "Modifier", commands: [
            CommandItem(id: 2548),
            CommandItem(id: 2549),
            CommandItem(id: 2550),
            CommandItem(id: 2551),
            CommandItem(id: 2552),
            CommandItem(id: 2553),
            CommandItem(id: 2554),
            CommandItem(id: 2555),
        ]),

        // Microphone
        CommandCategory2(name: "Microphone", commands: [
            CommandItem(id: 295),
            CommandItem(id: 296),
        ]),
    ]
}
