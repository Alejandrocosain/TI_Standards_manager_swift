import Fluent

struct CreateCodeLang: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(CodeLang.schema)
            .id()
            .field("name", .string, .required)
            .field("type", .string, .required)

            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(CodeLang.schema).delete()
    }
}
