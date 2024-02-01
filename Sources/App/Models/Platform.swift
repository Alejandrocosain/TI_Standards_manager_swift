//
//  File.swift
//  
//
//  Created by Alejandro Cosain on 02/02/24.
//

import Vapor
import Fluent

final class Platform: Model, Content {
    static let schema = "platforms"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "ip")
    var ip: String
    
    @Field(key: "description")
    var description: String
    
    @OptionalParent(key: "plat_admin")
    var platAdmin: User?
    
    @Siblings(through: PlatformCodeLangPivot.self, from: \.$platform, to: \.$codeLang)
    var codeLangs: [CodeLang]
    
    @Parent(key: "creator_user")
    var platformCreator: User
    
    init() {}
    
    init(id: UUID? = nil, name: String, ip: String, description: String, platAdminID: User.IDValue? = nil, platformCreatorID: User.IDValue) {
        self.id = id
        self.name = name
        self.ip = ip
        self.description = description
        self.$platAdmin.id = platAdminID
        self.$platformCreator.id = platformCreatorID
    }
    
    struct Public: Content {
        let id: UUID
        let name: String
        let ip: String
        let description: String
        let platAdmin: User.Public?
        let codeLangs: [CodeLang]
        let platformCreator: User.Public
        
    }
    
}


extension Platform {
    func asPublic() throws -> Public {
        return Public(id: try requireID(), name: name, ip: ip, description: description, platAdmin: try platAdmin?.asPublic(), codeLangs: codeLangs, platformCreator: try platformCreator.asPublic())
    }
    
}
