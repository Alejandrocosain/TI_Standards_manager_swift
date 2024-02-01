import Fluent
import Vapor

func routes(_ app: Application) throws {
   

    try app.register(collection: UserController())
    try app.register(collection: DatabaseTableController())
    try app.register(collection: PlatformController())
    try app.register(collection: CodeLangController())
    try app.register(collection: ModelMLController())
    try app.register(collection: StandardController())
}
