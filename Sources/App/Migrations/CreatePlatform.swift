import Fluent

struct CreatePlatform: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Platform.schema)
            .id()
            .field("name", .string, .required)
            .field("ip", .string, .required)
            .field("description", .string, .required)
            .field("plat_admin", .uuid, .references(User.schema, "id"))
            .field("creator_user", .uuid, .references(User.schema, "id"))
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Platform.schema).delete()
    }
}
