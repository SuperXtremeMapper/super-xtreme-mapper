//
//  MIDIUtilities.swift
//  XtremeMapping
//

import Foundation

/// Converts a MIDI note number (0-127) to a note name with octave.
/// Middle C (note 60) is C4.
func midiNoteToName(_ note: Int) -> String {
    let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    let noteName = noteNames[note % 12]
    let octave = (note / 12) - 1
    return "\(noteName)\(octave)"
}
