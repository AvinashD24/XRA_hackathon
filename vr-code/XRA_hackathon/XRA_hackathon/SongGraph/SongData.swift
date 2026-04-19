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

        let parsed = lines.compactMap { SongLoader.parseRow($0, bundle: bundle) }
        print("SongLoader: loaded \(parsed.count) songs from \(csvName).csv")
        return parsed
    }

    /// Handles two CSV layouts:
    /// - 8 columns: track_id, x, y, z, title, artist, preview_url, photo_url
    /// - 9 columns: track_id, x, y, z, title, artist, isrc, preview_url, photo_url
    nonisolated private static func parseRow(_ line: String, bundle: Bundle) -> SongData? {
        let fields = parseCSVRow(line)
        guard fields.count >= 8 else { return nil }

        guard let x = Float(fields[1]),
              let y = Float(fields[2]),
              let z = Float(fields[3]) else { return nil }

        let trackId = fields[0]
        let title = fields[4]
        let artist = fields[5]
        guard !trackId.isEmpty else { return nil }

        // Auto-detect format: 9+ columns means ISRC is at index 6
        let rawPlayback: String
        let rawPhoto: String
        if fields.count >= 9 {
            // 9-col: ..., isrc, preview_url, photo_url
            rawPlayback = fields[7].trimmingCharacters(in: .whitespaces)
            rawPhoto = fields[8].trimmingCharacters(in: .whitespaces)
        } else {
            // 8-col: ..., preview_url, photo_url
            rawPlayback = fields[6].trimmingCharacters(in: .whitespaces)
            rawPhoto = fields[7].trimmingCharacters(in: .whitespaces)
        }

        return SongData(
            id: trackId,
            position: SIMD3<Float>(x, y, z),
            title: title,
            artist: artist,
            playbackURL: resolveResourceURL(from: rawPlayback, bundle: bundle),
            photoURL: resolveResourceURL(from: rawPhoto, bundle: bundle)
        )
    }

    nonisolated private static func resolveResourceURL(from rawValue: String, bundle: Bundle) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let remoteURL = URL(string: value), remoteURL.scheme != nil {
            return remoteURL
        }

        if value.hasPrefix("/") {
            return URL(fileURLWithPath: value)
        }

        let nsValue = value as NSString
        let resource = nsValue.deletingPathExtension
        let ext = nsValue.pathExtension

        if !resource.isEmpty,
           !ext.isEmpty,
           let bundledURL = bundle.url(forResource: resource, withExtension: ext) {
            return bundledURL
        }

        if let resourceURL = bundle.resourceURL {
            let candidate = resourceURL.appendingPathComponent(value)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return URL(fileURLWithPath: value)
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
        // Prefer final_data (fewer songs, similar preview coverage)
        songs = SongLoader.load(from: "final_data")
        if songs.isEmpty {
            songs = SongLoader.load(from: "final_data2")
        }
        if songs.isEmpty {
            songs = SongLoader.load(from: "songs_sample")
        }
        songs.sort { lhs, rhs in
            simd_length_squared(lhs.position) < simd_length_squared(rhs.position)
        }
        print("SongStore: finished load. songs.count = \(songs.count)")
    }
}
