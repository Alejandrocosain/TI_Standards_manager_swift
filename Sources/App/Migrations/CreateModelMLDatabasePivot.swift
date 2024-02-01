import Fluent

struct CreateModelMLDatabasePivot: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(ModelMLDatabasePivot.schema)
            .id()
            .field("modelml_id", .uuid, .required, .references(ModelML.schema, "id"))
            .field("database_id", .uuid, .required, .references(DatabaseKelpel.schema, "id"))
            .field("to_validate", .int, .required)
            .field("validated", .int, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(ModelMLDatabasePivot.schema).delete()
    }
}
