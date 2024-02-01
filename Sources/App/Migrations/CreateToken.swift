import Fluent

struct CreateToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Token.schema)
            .id()
            .field("user_id", .uuid, .required,.references(User.schema, "id"))
            .field("value", .string, .required)
            .unique(on: "value")
            .field("expires_at", .datetime)
            .field("created_at", .datetime, .required)
      
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Token.schema).delete()
    }
}
