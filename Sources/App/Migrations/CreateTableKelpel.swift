import Fluent

struct CreateTableKelpel: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(TableKelpel.schema)
            .id()
            .field("name", .string, .required)
            .field("description", .string, .required)
            .field("database", .uuid, .references(DatabaseKelpel.schema, "id"))

            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(TableKelpel.schema).delete()
    }
}
