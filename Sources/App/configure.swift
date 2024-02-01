import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? 5435,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "cosain_architect_db",
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)
    
    app.migrations.add(CreateUser())
    app.migrations.add(CreateToken())
    app.migrations.add(CreateDatabaseKelpel())
    app.migrations.add(CreatePlatform())
    app.migrations.add(CreateStandard())
    app.migrations.add(CreateTableKelpel())

    app.migrations.add(CreateCodeLang())
    app.migrations.add(CreateModelML())
    app.migrations.add(CreateModelMLDatabasePivot())
    app.migrations.add(CreateModelMLPlatformPivot())
    app.migrations.add(CreateModelMLStandardPivot())
    app.migrations.add(CreatePlatformCodeLangPivot())

    try app.autoMigrate().wait()
    // register routes
    try routes(app)
}
