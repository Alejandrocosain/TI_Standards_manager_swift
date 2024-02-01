import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(User.schema)
            .id()
            .field("username", .string, .required)
            .field("password_hash", .string, .required)
            .field("role", .string, .required)
            .field("full_name", .string, .required)
            .field("employee_id", .int, .required)
            .field("job", .string, .required)
            .field("creation_date", .datetime )
            .field("update_date", .datetime)

            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(User.schema).delete()
    }
}
