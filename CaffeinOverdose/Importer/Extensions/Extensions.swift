//
//  Extensions.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/11/25.
//
import Foundation

public extension URL {
    var isDirectoryURL: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? hasDirectoryPath
    }
}
