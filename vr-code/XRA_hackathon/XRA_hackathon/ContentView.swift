//
//  ContentView.swift
//  XRA_hackathon
//
//  Created by iguest on 4/18/26.
//

import SwiftUI

struct ContentView: View {

    @Environment(AppSettings.self) private var appSettings
    @Environment(SongStore.self) private var songStore
    @Environment(\.openImmersiveSpace) private var openImmersive
    @Environment(\.dismissImmersiveSpace) private var dismissImmersive

    @State private var isImmersiveOpen = false

    var body: some View {
        @Bindable var appSettings = appSettings

        VStack(spacing: 24) {
            Text("Song Space")
                .font(.largeTitle.bold())

            Text("\(songStore.songs.count) songs loaded")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text("Graphics")
                    .font(.headline)

                HStack {
                    Text("Visible spheres")
                    Spacer()
                    Picker("Visible spheres", selection: $appSettings.maxVisibleSphereCount) {
                        ForEach(AppSettings.sphereCountPresets, id: \.self) { count in
                            Text("\(min(count, songStore.songs.count))")
                                .tag(count)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .disabled(isImmersiveOpen)

                Text("Show up to \(min(appSettings.maxVisibleSphereCount, songStore.songs.count)) spheres in Vision Pro. Lower counts are safer if the immersive space is crashing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 520, alignment: .leading)
            .glassBackgroundEffect()

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
        .environment(AppSettings())
        .environment(SongStore())
}
