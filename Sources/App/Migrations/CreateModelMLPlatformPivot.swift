import Fluent

struct CreateModelMLPlatformPivot: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(ModelMLPlatformPivot.schema)
            .id()
            .field("modelml_id", .uuid, .required, .references(ModelML.schema, "id"))
            .field("platform_id", .uuid, .required, .references(Platform.schema, "id"))
            .field("to_validate", .int, .required)
            .field("validated", .int, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(ModelMLPlatformPivot.schema).delete()
    }
}
