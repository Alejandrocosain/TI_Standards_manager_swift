import Fluent

struct CreateModelMLStandardPivot: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(ModelMLStandardPivot.schema)
            .id()
            .field("modelml_id", .uuid, .required, .references(ModelML.schema, "id"))
            .field("standard_id", .uuid, .required, .references(Standard.schema, "id"))
            .field("validated", .int, .required)
            .field("to_validate", .int, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(ModelMLStandardPivot.schema).delete()
    }
}
