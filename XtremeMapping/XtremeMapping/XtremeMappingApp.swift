//
//  XtremeMappingApp.swift
//  XtremeMapping
//
//  Created by Noah Raford on 13/01/2026.
//

import SwiftUI

@main
struct XtremeMappingApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: XtremeMappingDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
