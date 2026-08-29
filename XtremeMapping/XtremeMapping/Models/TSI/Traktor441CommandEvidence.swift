//
//  Traktor441CommandEvidence.swift
//  XtremeMapping
//

import Foundation

/// Conservative command-direction evidence from the pinned Traktor 4.4.1 audit.
///
/// A direction records a locally observed creation capability. It does not
/// assert that the command is impossible to use in an unobserved direction.
enum Traktor441CommandEvidence {
    static let inputOnlyIDs: Set<Int> = Set(
        [60, 64, 232, 246, 255, 256, 258, 266, 267, 268, 326, 349, 362, 363,
         364, 740, 2249, 2253, 2331, 3048, 5129]
        + Array(601...664)
    )

    static let outputOnlyIDs: Set<Int> = Set(
        [247, 323, 512, 513, 2238, 2302, 2333, 2334, 2335, 2336, 2337, 2338,
         2339, 2340, 2591, 2811]
        + Array(665...727)
    )

    static let bothDirectionIDs: Set<Int> = Set(
        [7, 9, 19, 69, 119, 120, 123, 125, 202, 204, 206, 235, 237, 238,
         265, 321, 322, 338, 339, 348, 400, 402, 406, 729, 730, 731, 732,
         733, 2002, 2004, 2187, 2192, 2196, 2248, 2301, 2311, 2313, 2328,
         2350, 2351, 2401, 2402, 2403, 2404, 2408, 2409, 2473, 2548, 2549,
         2550, 2551, 2552, 2553, 2554, 2555, 4209]
        + Array(741...756)
    )

    static let correctedOutputOnlyIDs: Set<Int> = [
        201, 203, 736, 2688, 2689, 2703, 2712, 2713,
    ]

    static let correctedBothDirectionIDs: Set<Int> = [738]

    /// Commands whose pinned 4.4.1 evidence plus a local multi-version
    /// compatibility corpus establish both DCBL directions. These observations
    /// broaden direction availability only; identity remains pinned to 4.4.1.
    static let compatibilityCorpusBothDirectionIDs: Set<Int> = [
        201, 323, 362, 363, 364, 740, 2253, 2302, 5129,
    ]

    /// Commands observed as inputs in the complete Traktor 4.5.1 Xone:K3
    /// Remix benchmark export. Direction evidence is intentionally limited to
    /// input; it does not claim output support that the fixture does not prove.
    static let compatibilityCorpusInputOnlyIDs: Set<Int> = [
        239, 249, 250, 251, 259,
    ]

    static func supportedDirections(for commandID: Int) -> Set<IODirection> {
        if compatibilityCorpusBothDirectionIDs.contains(commandID) {
            return [.input, .output]
        }
        if compatibilityCorpusInputOnlyIDs.contains(commandID) {
            return [.input]
        }
        if inputOnlyIDs.contains(commandID) {
            return [.input]
        }
        if outputOnlyIDs.contains(commandID) || correctedOutputOnlyIDs.contains(commandID) {
            return [.output]
        }
        if bothDirectionIDs.contains(commandID) || correctedBothDirectionIDs.contains(commandID) {
            return [.input, .output]
        }
        return []
    }
}
