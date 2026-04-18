//
//  XRA_hackathonApp.swift
//  XRA_hackathon
//
//  Created by iguest on 4/18/26.
//

import SwiftUI

@main
struct XRA_hackathonApp: App {

    @State private var songStore = SongStore()
    @State private var playlistStore = PlaylistStore()
    @State private var audioService = AudioPlaybackService()
    @State private var handTracking = HandTrackingManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(songStore)
                .environment(playlistStore)
                .environment(audioService)
                .environment(handTracking)
                .task {
                    songStore.loadSample()
                    handTracking.updateSongList(songStore.songs)
                }
        }
        .windowResizability(.contentSize)

        ImmersiveSpace(id: "SongGraph") {
            ImmersiveView()
                .environment(songStore)
                .environment(playlistStore)
                .environment(audioService)
                .environment(handTracking)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
