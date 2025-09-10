//
//  BookmarkStore.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//
import Foundation

struct BookmarkStore {
    private static let key = "BookmarkedFolderURLs"

    static func save(urls: [URL]) {
        // path -> bookmarkData
        let dict: [String: Data] = Dictionary(uniqueKeysWithValues: urls.compactMap { url in
            guard let data = try? url.bookmarkData(options: .withSecurityScope,
                                                   includingResourceValuesForKeys: nil,
                                                   relativeTo: nil) else { return nil }
            return (url.path, data)
        })
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("BookmarkStore.save error:", error)
        }
    }

    static func restore() -> [URL] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            guard let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Data]
            else { return [] }

            return dict.compactMap { (_, bmData) in
                var isStale = false
                return try? URL(resolvingBookmarkData: bmData,
                                options: .withSecurityScope,
                                relativeTo: nil,
                                bookmarkDataIsStale: &isStale)
            }
        } catch {
            print("BookmarkStore.restore error:", error)
            return []
        }
    }
}
