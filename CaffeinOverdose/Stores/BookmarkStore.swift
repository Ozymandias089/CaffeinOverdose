//
//  BookmarkStore.swift
//  CaffeinOverdose
//
//  Security-scoped bookmarks helper for sandboxed folder access.
//  - Save / restore with stale bookmark auto-repair
//  - Start/stop accessing helpers
//

import Foundation

enum BookmarkStore {

    // MARK: Storage
    private static let key = "BookmarkedFolderURLs.v2"

    /// Load raw dict from UserDefaults (path -> bookmarkData)
    private static func loadDict() -> [String: Data] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        do {
            return try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Data] ?? [:]
        } catch {
            print("[BookmarkStore] load error:", error)
            return [:]
        }
    }

    /// Save raw dict to UserDefaults
    @discardableResult
    private static func saveDict(_ dict: [String: Data]) -> Bool {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
            UserDefaults.standard.set(data, forKey: key)
            return true
        } catch {
            print("[BookmarkStore] save error:", error)
            return false
        }
    }

    // MARK: Public API

    /// Add or update a bookmark for a folder URL.
    static func add(url: URL) {
        guard url.hasDirectoryPath else { return }
        do {
            let data = try url.bookmarkData(options: .withSecurityScope,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
            var dict = loadDict()
            dict[url.path] = data
            _ = saveDict(dict)
        } catch {
            print("[BookmarkStore] add error:", error)
        }
    }

    /// Remove a specific path bookmark (if exists).
    static func remove(path: String) {
        var dict = loadDict()
        dict.removeValue(forKey: path)
        _ = saveDict(dict)
    }

    /// Remove all bookmarks.
    static func removeAll() {
        _ = saveDict([:])
    }

    /// Restore all bookmarked folder URLs.
    /// - Returns: Resolved URLs that could be created (not started yet).
    static func restoreAll() -> [URL] {
        var dict = loadDict()
        var out: [URL] = []
        var changed = false

        for (path, bmData) in dict {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: bmData,
                                  options: .withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)
                // If stale, re-create bookmark and overwrite
                if isStale {
                    let fresh = try url.bookmarkData(options: .withSecurityScope,
                                                     includingResourceValuesForKeys: nil,
                                                     relativeTo: nil)
                    dict[path] = fresh
                    changed = true
                }
                out.append(url)
            } catch {
                print("[BookmarkStore] restore fail for \(path):", error)
                dict.removeValue(forKey: path)
                changed = true
            }
        }

        if changed { _ = saveDict(dict) }
        return out
    }

    /// Convenience: restore and startAccessing for all valid URLs.
    /// - Returns: URLs that successfully started access.
    @discardableResult
    static func restoreAndStartAccessingAll() -> [URL] {
        restoreAll().compactMap { url in
            url.startAccessingSecurityScopedResource() ? url : nil
        }
    }

    /// Stop accessing for the provided URLs.
    static func stopAccessing(urls: [URL]) {
        urls.forEach { $0.stopAccessingSecurityScopedResource() }
    }

    /// Housekeeping: remove entries that are no longer reachable on disk.
    static func pruneMissingPaths() {
        var dict = loadDict()
        var changed = false
        for (path, _) in dict {
            if !FileManager.default.fileExists(atPath: path) {
                dict.removeValue(forKey: path)
                changed = true
            }
        }
        if changed { _ = saveDict(dict) }
    }

    /// Debug helper
    static func listPaths() -> [String] {
        Array(loadDict().keys).sorted()
    }
}
