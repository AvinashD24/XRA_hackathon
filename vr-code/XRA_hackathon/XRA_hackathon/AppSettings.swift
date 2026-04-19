//
//  AppSettings.swift
//  XRA_hackathon
//

import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    static let sphereCountPresets: [Int] = [100, 200, 300, 500, 800, 1200]
    static let defaultSphereCount = 300

    var maxVisibleSphereCount: Int = defaultSphereCount
}
