//
//  TestFixtures.swift
//  XtremeMappingTests
//

import Foundation
@testable import XtremeMapping

extension MappingEntry {
    static var fullFieldSentinel: MappingEntry {
        MappingEntry(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            commandID: 4242,
            ioType: .output,
            assignment: .remixDeckDSlot4,
            interactionMode: .decrement,
            midiChannel: 16,
            midiNote: 127,
            modifier1Condition: ModifierCondition(modifier: 1, value: 7),
            modifier2Condition: ModifierCondition(modifier: 8, value: 3),
            comment: "Macro 🧪\nsecond line",
            controllerType: .encoder,
            invert: true,
            softTakeover: true,
            setToValue: 0.75,
            rotarySensitivity: 2.5,
            rotaryAcceleration: 0.8,
            encoderMode: .mode3Fh41h,
            rawDCDTEncoderMode: 3,
            autoRepeat: true,
            ledMinRangeType: 2,
            ledMinRangeData: -3,
            ledMaxRangeType: 4,
            ledMaxRangeData: 9,
            ledMinMidi: 5,
            ledMaxMidi: 120,
            ledInvert: true,
            ledBlend: true,
            resolution: 2
        )
    }
}
