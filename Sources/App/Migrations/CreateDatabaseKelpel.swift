import Fluent

struct CreateDatabaseKelpel: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(DatabaseKelpel.schema)
            .id()
            .field("name", .string, .required)
            .field("ip", .string, .required)
            .field("description", .string, .required)
            .field("db_admin", .uuid, .references(User.schema, "id"))
            .field("creator_id", .uuid, .references(User.schema, "id"))
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(DatabaseKelpel.schema).delete()
    }
}
