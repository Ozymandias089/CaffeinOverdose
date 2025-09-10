//
//  LibraryStore.swift
//  CaffeinOverdose
//
//  v1: 로컬 JSON 카탈로그 방식 (~/Pictures/CaffeinOverdose.coffeelib/db.json)
//  - 플랫 배열로 저장/로드
//  - 앱 시작 시 트리 재구성
//

import Foundation

@MainActor
final class LibraryStore: ObservableObject {

    // MARK: - Published State

    @Published var root: MediaFolder = .init(name: "Library", path: "/")
    @Published var selectedFolder: MediaFolder?
    @Published var selectedItem: MediaItem?

    // MARK: - Init

    init() {
        // 라이브러리 패키지/폴더 보장
        do { try LibraryLocation.ensureExists() }
        catch { print("Library ensure error:", error) }

        // DB 로드 → 트리 재구성
        loadDB()

        // 초기 선택 폴더
        if selectedFolder == nil { selectedFolder = root }
    }

    // MARK: - Public API (고수준)

    /// 카탈로그 디스크 → 메모리 로드
    func loadDB() {
        do {
            let data = try Data(contentsOf: LibraryLocation.dbFile)

            // 빈 JSON("{}")일 수 있으니 방어
            if let top = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               top.isEmpty {
                root = MediaFolder(name: "Library", path: "/")
                return
            }

            let dec = JSONDecoder()
            let catalog = try dec.decode(CatalogV1.self, from: data)
            let items = catalog.items.map { MediaItem.fromRecord($0) }
            rebuildTree(with: items)
        } catch {
            // 파일 없음/파싱 실패 → 초기화
            root = MediaFolder(name: "Library", path: "/")
        }
    }

    /// 메모리 트리 → 카탈로그 디스크 저장
    func saveDB() {
        let allItems = flattenItems(from: root)
        let records = allItems.map { $0.toRecord() }
        let catalog = CatalogV1(version: 1, items: records)

        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(catalog)
            try data.write(to: LibraryLocation.dbFile, options: .atomic)
        } catch {
            print("saveDB error:", error)
        }
    }

    /// 외부에서 읽어온/가져온 아이템을 라이브러리에 합치고 즉시 저장
    func addImportedItems(_ newItems: [MediaItem]) {
        var merged = flattenItems(from: root)
        merged.append(contentsOf: newItems)
        rebuildTree(with: merged)
        saveDB()
    }

    /// 라이브러리 전체 리셋 (주의: db.json도 초기화)
    func resetLibrary() {
        root = MediaFolder(name: "Library", path: "/")
        selectedFolder = root
        selectedItem = nil
        do {
            try Data("{}".utf8).write(to: LibraryLocation.dbFile, options: .atomic)
        } catch {
            print("resetLibrary error:", error)
        }
    }

    // MARK: - Tree Rebuild / Flatten

    /// 플랫 MediaItem 배열로부터 폴더 트리 재구성
    func rebuildTree(with items: [MediaItem]) {
        let rootNode = MediaFolder(name: "Library", path: "/")

        // path(예: "/Untitled/Child") → 폴더 노드
        var folderMap: [String: MediaFolder] = ["/": rootNode]

        func ensureFolder(_ displayPath: String) -> MediaFolder {
            if let f = folderMap[displayPath] { return f }

            // 상위 폴더 먼저 생성
            let parentPath: String = {
                let comps = displayPath.split(separator: "/")
                if comps.count <= 1 { return "/" }
                let parent = comps.dropLast().joined(separator: "/")
                return parent.hasPrefix("/") ? parent : "/" + parent
            }()

            let parent = ensureFolder(parentPath)
            let name = displayPath.split(separator: "/").last.map(String.init) ?? "Library"
            let node = MediaFolder(name: name, path: displayPath)
            folderMap[displayPath] = node
            parent.subfolders.append(node)
            return node
        }

        // 아이템을 해당 폴더에 배치
        for item in items {
            let path = item.parentFolderPath.isEmpty ? "/" : item.parentFolderPath
            let folder = ensureFolder(path)
            folder.items.append(item)
        }

        // 정렬 정책(원하면 커스터마이즈 가능)
        for (_, folder) in folderMap {
            folder.subfolders.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
            folder.items.sort { $0.filename.localizedCompare($1.filename) == .orderedAscending }
        }

        self.root = rootNode
    }

    /// 폴더 트리 전체를 플랫 MediaItem 배열로 변환
    private func flattenItems(from folder: MediaFolder) -> [MediaItem] {
        var out = folder.items
        for sub in folder.subfolders {
            out.append(contentsOf: flattenItems(from: sub))
        }
        return out
    }

    // MARK: - 편의 함수

    /// 폴더 선택
    func selectFolder(_ folder: MediaFolder?) {
        selectedFolder = folder
        // 폴더가 바뀌면 상세 아이템 선택도 초기화
        if selectedItem.map({ $0.parentFolderPath }) != folder?.path {
            selectedItem = nil
        }
    }

    /// 상세 아이템 선택
    func selectItem(_ item: MediaItem?) {
        selectedItem = item
    }
    
    /// LibraryStore.swift 안에 추가
    func folder(at path: String) -> MediaFolder? {
        if root.path == path { return root }
        var stack: [MediaFolder] = [root]
        while let f = stack.popLast() {
            if f.path == path { return f }
            stack.append(contentsOf: f.subfolders)
        }
        return nil
    }

}
