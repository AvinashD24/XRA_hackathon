//
//  ConfirmPlaylistView.swift
//  XRA_hackathon
//

import SwiftUI

struct ConfirmPlaylistView: View {

    @Environment(HandTrackingManager.self) private var handTracking
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(handTracking.selectedSongIds.count) songs selected")
                    .font(.headline)
                Text("Create a playlist?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                onConfirm()
            } label: {
                Label("Create", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)

            Button {
                handTracking.dismissSelection()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonBorderShape(.circle)
        }
        .padding(14)
        .glassBackgroundEffect()
    }
}
