//
//  SongData.swift
//  XRA_hackathon
//

import Foundation
import simd
import Observation

struct SongData: Identifiable, Hashable {
    let id: String
    let position: SIMD3<Float>
    let title: String
    let artist: String
    let playbackURL: URL?
    let photoURL: URL?
}

enum SongLoader {
    static func load(from csvName: String, bundle: Bundle = .main) -> [SongData] {
        guard let url = bundle.url(forResource: csvName, withExtension: "csv"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            print("SongLoader: could not find \(csvName).csv in bundle")
            return []
        }

        var lines = raw.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { return [] }
        lines.removeFirst()

        return lines.compactMap(parseRow)
    }

    private static func parseRow(_ line: String) -> SongData? {
        let fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 8 else { return nil }

        guard let x = Float(fields[1]),
              let y = Float(fields[2]),
              let z = Float(fields[3]) else { return nil }

        return SongData(
            id: fields[0],
            position: SIMD3<Float>(x, y, z),
            title: fields[4],
            artist: fields[5],
            playbackURL: URL(string: fields[6]),
            photoURL: URL(string: fields[7])
        )
    }
}

@MainActor
@Observable
final class SongStore {
    var songs: [SongData] = []

    func loadSample() {
        songs = SongLoader.load(from: "songs_sample")
    }
}
