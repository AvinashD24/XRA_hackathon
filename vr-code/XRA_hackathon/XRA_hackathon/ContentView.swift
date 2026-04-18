//
//  ContentView.swift
//  XRA_hackathon
//
//  Created by iguest on 4/18/26.
//

import SwiftUI

struct ContentView: View {

    @Environment(SongStore.self) private var songStore
    @Environment(\.openImmersiveSpace) private var openImmersive
    @Environment(\.dismissImmersiveSpace) private var dismissImmersive

    @State private var isImmersiveOpen = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Song Space")
                .font(.largeTitle.bold())

            Text("\(songStore.songs.count) songs loaded")
                .foregroundStyle(.secondary)

            Button(isImmersiveOpen ? "Exit Song Space" : "Enter Song Space") {
                Task {
                    if isImmersiveOpen {
                        await dismissImmersive()
                        isImmersiveOpen = false
                    } else {
                        if case .opened = await openImmersive(id: "SongGraph") {
                            isImmersiveOpen = true
                        }
                    }
                }
            }
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .glassBackgroundEffect()
        }
        .padding(40)
    }
}

#Preview(windowStyle: .plain) {
    ContentView()
        .environment(SongStore())
}
