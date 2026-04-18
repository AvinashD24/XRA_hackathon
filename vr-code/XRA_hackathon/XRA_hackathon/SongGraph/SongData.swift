//
//  SongData.swift
//  XRA_hackathon
//

import Foundation
import simd
import Observation

struct SongData: Identifiable, Hashable, Sendable {
    let id: String
    let position: SIMD3<Float>
    let title: String
    let artist: String
    let playbackURL: URL?
    let photoURL: URL?
}

nonisolated enum SongLoader {
    nonisolated static func load(from csvName: String, bundle: Bundle = .main) -> [SongData] {
        guard let url = bundle.url(forResource: csvName, withExtension: "csv") else {
            print("SongLoader: could not find \(csvName).csv in bundle")
            return []
        }
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            print("SongLoader: failed to read \(csvName).csv")
            return []
        }

        var lines = raw.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { return [] }
        lines.removeFirst()

        let parsed = lines.compactMap { SongLoader.parseRow($0) }
        print("SongLoader: loaded \(parsed.count) songs from \(csvName).csv")
        return parsed
    }

    nonisolated private static func parseRow(_ line: String) -> SongData? {
        let fields = parseCSVRow(line)
        guard fields.count >= 8 else { return nil }

        guard let x = Float(fields[1]),
              let y = Float(fields[2]),
              let z = Float(fields[3]) else { return nil }

        let trackId = fields[0]
        let title = fields[4]
        let artist = fields[5]
        guard !trackId.isEmpty else { return nil }

        let rawPlayback = fields[6].trimmingCharacters(in: .whitespaces)
        let rawPhoto = fields[7].trimmingCharacters(in: .whitespaces)

        return SongData(
            id: trackId,
            position: SIMD3<Float>(x, y, z),
            title: title,
            artist: artist,
            playbackURL: rawPlayback.isEmpty ? nil : URL(string: rawPlayback),
            photoURL: rawPhoto.isEmpty ? nil : URL(string: rawPhoto)
        )
    }

    /// Minimal RFC-4180-style CSV field splitter: handles quoted fields
    /// and escaped "" inside quotes. Works on a single line.
    nonisolated private static func parseCSVRow(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let c = line[i]
            if inQuotes {
                if c == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex, line[next] == "\"" {
                        current.append("\"")
                        i = line.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else {
                if c == "," {
                    fields.append(current)
                    current = ""
                } else if c == "\"" {
                    inQuotes = true
                } else {
                    current.append(c)
                }
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }
}

@MainActor
@Observable
final class SongStore {
    var songs: [SongData] = []

    init() {
        loadSample()
    }

    func loadSample() {
        print("SongStore: starting load. Bundle path = \(Bundle.main.bundlePath)")
        if let url = Bundle.main.url(forResource: "final_data", withExtension: "csv") {
            print("SongStore: found final_data.csv at \(url.path)")
        } else {
            print("SongStore: final_data.csv NOT FOUND in bundle")
        }
        songs = SongLoader.load(from: "final_data")
        if songs.isEmpty {
            songs = SongLoader.load(from: "songs_sample")
        }
        print("SongStore: finished load. songs.count = \(songs.count)")
    }
}
