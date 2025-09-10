//
//  LibraryLocation.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import Foundation

enum LibraryLocation {
    // ~/Pictures/CaffeinOverdose.coffeelib
    static var root: URL {
        FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CaffeinOverdose.coffeelib", isDirectory: true)
    }
    static var media: URL { root.appendingPathComponent("media", isDirectory: true) }
    static var thumbs: URL { root.appendingPathComponent("thumbs", isDirectory: true) }
    static var dbFile: URL { root.appendingPathComponent("db.json") }

    /// 권한은 entitlements가 보장. 북마크/withAccess 불필요.
    @discardableResult
    static func ensureExists() throws -> Bool {
        let fm = FileManager.default
        for dir in [root, media, thumbs] {
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
        if !fm.fileExists(atPath: dbFile.path) {
            try Data("{}".utf8).write(to: dbFile, options: .atomic)
        }
        return true
    }
}
