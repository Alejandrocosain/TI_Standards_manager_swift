import Fluent

struct CreateStandard: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Standard.schema)
            .id()
            .field("name", .string, .required)
            .field("type", .string, .required)
            .field("description", .string, .required)

            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Standard.schema).delete()
    }
}
