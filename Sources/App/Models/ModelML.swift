//
//  File.swift
//  
//
//  Created by Alejandro Cosain on 02/02/24.
//

import Vapor
import Fluent

final class ModelML: Model, Content {
    static let schema = "model_ml"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Parent(key: "owner")
    var owner: User

    @Field(key: "description")
    var description: String
    
    @Field(key: "latest_version_validated")
    var latestVersionValidated: Int
    
    @Field(key: "status")
    var status: String
    
    @Siblings(through: ModelMLDatabasePivot.self, from: \.$modelML, to: \.$database)
    var databases: [DatabaseKelpel]
    
    @Siblings(through: ModelMLPlatformPivot.self, from: \.$modelML, to: \.$platform)
    var platforms: [Platform]
    
    @Siblings(through: ModelMLStandardPivot.self, from: \.$modelML, to: \.$standard)
    var standards: [Standard]
    
    @Parent(key: "model_creator")
    var modelCreator: User
    
    init() {}
    
    init(id: UUID? = nil, name: String, ownerID: User.IDValue, description: String, latestVersionValidated: Int, status: String, modelCreatorID: User.IDValue) {
        self.id = id
        self.name = name
        self.$owner.id = ownerID
        self.description = description
        self.latestVersionValidated = latestVersionValidated
        self.status = status
        self.$modelCreator.id = modelCreatorID
    }
    
    struct Public: Content {
        let id: UUID
        let name: String
        let owner: User.Public
        let description: String
        let latestVersionValidated: Int
        let status: String
        let databases: [DatabaseKelpel.Public]
        let platforms: [Platform.Public]
        let standards: [Standard]
        let modelCreator: User.Public
    }
    
    struct ViewPivot: Content {
        let id: UUID
        let name: String

    }
}

extension ModelML {
    func asPublic() throws -> Public {
        return Public(id: try requireID(), name: name, owner: try owner.asPublic(), description: description, latestVersionValidated: latestVersionValidated, status: status ,databases: try databases.map({try $0.asPublic()}),platforms: try platforms.map({try $0.asPublic()}),standards: standards, modelCreator: try modelCreator.asPublic())
    }
    func asViewPublic() throws -> ViewPivot {
        return ViewPivot(id: try requireID(), name: name)
    }
}
