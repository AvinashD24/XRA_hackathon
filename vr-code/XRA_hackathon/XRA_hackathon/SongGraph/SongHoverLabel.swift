//
//  SongHoverLabel.swift
//  XRA_hackathon
//
//  Shows album art, song title, and artist when the user gazes at a sphere.
//

import SwiftUI

struct SongHoverLabel: View {

    let song: SongData

    var body: some View {
        VStack(spacing: 6) {
            // Album artwork
            AsyncImage(url: song.photoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Rectangle().fill(.gray.opacity(0.3))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Song title
            Text(song.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            // Artist
            Text(song.artist)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(width: 140)
        .glassBackgroundEffect()
    }
}
