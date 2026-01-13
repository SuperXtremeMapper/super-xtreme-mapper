//
//  ContentView.swift
//  XtremeMapping
//
//  Created by Noah Raford on 13/01/2026.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: XtremeMappingDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(XtremeMappingDocument()))
}
