//
//  ContentView.swift
//  XtremeMapping
//
//  Created by Noah Raford on 13/01/2026.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: TraktorMappingDocument

    var body: some View {
        Text("Mappings: \(document.mappingFile.allMappings.count)")
    }
}

#Preview {
    ContentView(document: .constant(TraktorMappingDocument()))
}
