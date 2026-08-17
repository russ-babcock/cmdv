import Foundation
import GRDB

enum AppPaths {
    /// Everything CmdV stores is owner-only. The contents are, by definition,
    /// everything the user has copied — including whatever slipped past
    /// `ConcealedDetector`, which is a best-effort deny list rather than a
    /// guarantee. The default 0755/0644 would leave that readable by every
    /// other account on the machine. 0700 on the directories is the load-
    /// bearing part (no traversal, so the contents are unreachable whatever
    /// their own modes say); the file modes are defence in depth.
    ///
    /// Computed rather than stored: `[FileAttributeKey: Any]` isn't Sendable,
    /// so a static constant of that type is a strict-concurrency error.
    private static var directoryAttributes: [FileAttributeKey: Any] { [.posixPermissions: 0o700] }
    static var fileAttributes: [FileAttributeKey: Any] { [.posixPermissions: 0o600] }

    private static func makeDirectory(_ url: URL) -> URL {
        let fm = FileManager.default
        try? fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: directoryAttributes)
        // createDirectory only applies attributes to directories it creates, so
        // tighten existing ones too — installs that predate this are the whole
        // reason it matters.
        try? fm.setAttributes(directoryAttributes, ofItemAtPath: url.path)
        return url
    }

    static let applicationSupport: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = makeDirectory(base.appendingPathComponent("CmdV", isDirectory: true))
        // The subdirectories are created and tightened here, eagerly, rather
        // than being left to their own lazy initializers: those don't run until
        // the first image or payload is written, so an install carried over
        // from a build that made them 0755 would stay world-readable until the
        // user happened to copy an image.
        _ = makeDirectory(dir.appendingPathComponent("images", isDirectory: true))
        _ = makeDirectory(dir.appendingPathComponent("payloads", isDirectory: true))
        return dir
    }()

    static let databaseURL = applicationSupport.appendingPathComponent("cmdv.sqlite")

    static let imagesDirectory: URL = {
        makeDirectory(applicationSupport.appendingPathComponent("images", isDirectory: true))
    }()

    static let payloadsDirectory: URL = {
        makeDirectory(applicationSupport.appendingPathComponent("payloads", isDirectory: true))
    }()
}

enum AppDatabase {
    static func makeQueue(at url: URL = AppPaths.databaseURL) throws -> DatabaseQueue {
        var config = Configuration()
        config.foreignKeysEnabled = true
        let queue = try DatabaseQueue(path: url.path, configuration: config)
        try migrator.migrate(queue)
        restrictPermissions(of: url)
        return queue
    }

    /// SQLite creates the database file itself, honouring the process umask
    /// (0644 by default), so the mode has to be corrected afterwards. The
    /// sidecar files only exist in WAL mode but are tightened unconditionally:
    /// a `-wal` file holds committed rows that haven't been checkpointed yet,
    /// so it leaks exactly what the database does.
    private static func restrictPermissions(of url: URL) {
        let fm = FileManager.default
        for path in [url.path, url.path + "-wal", url.path + "-shm"] where fm.fileExists(atPath: path) {
            try? fm.setAttributes(AppPaths.fileAttributes, ofItemAtPath: path)
        }
    }
}
