import Fluent

struct CreatePlatformCodeLangPivot: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(PlatformCodeLangPivot.schema)
            .id()
            .field("platform_id", .uuid, .required, .references(Platform.schema, "id"))
            .field("codelang_id", .uuid, .required, .references(CodeLang.schema, "id"))
          
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(PlatformCodeLangPivot.schema).delete()
    }
}
