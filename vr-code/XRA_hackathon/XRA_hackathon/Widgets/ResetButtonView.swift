//
//  ResetButtonView.swift
//  XRA_hackathon
//

import SwiftUI

struct ResetButtonView: View {
    let onReset: () -> Void

    var body: some View {
        Button {
            onReset()
        } label: {
            Label("Reset", systemImage: "arrow.counterclockwise")
                .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .padding(8)
        .glassBackgroundEffect()
    }
}
