import Fluent

struct CreateModelML: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(ModelML.schema)
            .id()
            .field("name", .string, .required)
            .field("owner", .uuid, .required, .references(User.schema, "id"))
            .field("description", .string, .required)
            .field("latest_version_validated", .int, .required)
            .field("status", .string,.required)
            .field("model_creator", .uuid,.required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(ModelML.schema).delete()
    }
}
