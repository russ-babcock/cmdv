import GRDB

extension AppDatabase {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_createClip") { db in
            try db.create(table: "clip") { t in
                t.column("id", .text).primaryKey()
                t.column("createdAt", .datetime).notNull()
                t.column("lastUsedAt", .datetime).notNull()
                t.column("useCount", .integer).notNull().defaults(to: 0)

                t.column("kind", .text).notNull()
                t.column("plainText", .text)
                t.column("previewText", .text).notNull()
                t.column("payloadPath", .text)

                t.column("imagePath", .text)
                t.column("thumbPath", .text)
                t.column("pixelWidth", .integer)
                t.column("pixelHeight", .integer)
                t.column("byteSize", .integer)

                t.column("sourceBundleID", .text)
                t.column("sourceAppName", .text)

                t.column("isFavorite", .boolean).notNull().defaults(to: false)
                t.column("pinKey", .text)

                t.column("isConcealed", .boolean).notNull().defaults(to: false)
                t.column("expiresAt", .datetime)

                t.column("contentHash", .text).notNull()
            }

            try db.create(index: "clip_createdAt", on: "clip", columns: ["createdAt"])
            try db.create(index: "clip_contentHash", on: "clip", columns: ["contentHash"])
            try db.create(
                index: "clip_pinKey",
                on: "clip",
                columns: ["pinKey"],
                unique: true,
                condition: Column("pinKey") != nil
            )
        }

        return migrator
    }
}
