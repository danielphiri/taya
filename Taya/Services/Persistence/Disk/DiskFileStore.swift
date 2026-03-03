//
//  DiskFileStore.swift
//  Taya
//
//  Lightweight persistence for MemoryCards.
//

import Foundation

/// Minimal file I/O abstraction so persistence can be tested without touching disk.
protocol FileStore: Sendable {
    func fileExists(at url: URL) -> Bool
    func read(from url: URL) throws -> Data
    func write(_ data: Data, to url: URL) throws
}

/// File store backed by `FileManager` and atomic `Data` writes.
struct DiskFileStore: FileStore {
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
}
