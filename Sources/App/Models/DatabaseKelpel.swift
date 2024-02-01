import Fluent
import Vapor

final class DatabaseKelpel: Model, Content {
    static let schema = "database"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String
    
    @Field(key: "ip")
    var ip: String
    
    @Field(key: "description")
    var description: String
    
    @OptionalParent(key:"db_admin")
    var dbAdmin: User?
    
    @Children(for: \.$database)
    var tables: [TableKelpel]
    
    @Parent(key: "creator_id")
    var creatorUser: User
    
    init() {}
    
    init(id: UUID? = nil, name: String, ip: String, description: String, creatorUserId: User.IDValue) {
        self.id = id
        self.name = name
        self.ip = ip
        self.description = description
        self.$creatorUser.id = creatorUserId
    }
    
    struct Public: Content {
        let id: UUID
        let name: String
        let ip: String
        let description: String
        let dbAdmin: User.Public?
        let tables: [TableKelpel]
        let creatorUser: User.Public
        
    }
    
}

extension DatabaseKelpel {
    
    func asPublic() throws -> Public {
        return Public(id: try requireID(), name: name, ip: ip, description: description, dbAdmin: try dbAdmin?.asPublic(),tables:  tables, creatorUser: try creatorUser.asPublic())
    }
    
}
