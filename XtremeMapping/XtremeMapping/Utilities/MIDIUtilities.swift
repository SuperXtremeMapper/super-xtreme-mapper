//
//  MIDIUtilities.swift
//  XtremeMapping
//

import Foundation

/// Converts a MIDI note number (0-127) to a note name with octave.
/// Middle C (note 60) is C4.
nonisolated func midiNoteToName(_ note: Int) -> String {
    precondition((0...127).contains(note), "MIDI note must be in 0...127")
    let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    let noteName = noteNames[note % 12]
    let octave = (note / 12) - 1
    return "\(noteName)\(octave)"
}
