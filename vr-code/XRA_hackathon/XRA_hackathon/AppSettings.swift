//
//  AppSettings.swift
//  XRA_hackathon
//

import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    static let sphereCountPresets: [Int] = [200, 400, 600, 800, 1000, 1200]
    static let defaultSphereCount = 1000

    var maxVisibleSphereCount: Int = defaultSphereCount

    /// When true, only songs with a working playback preview URL are shown.
    var onlyShowPreviewable: Bool = false
}
