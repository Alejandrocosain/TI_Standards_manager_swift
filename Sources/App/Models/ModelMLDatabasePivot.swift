//
//  File.swift
//  
//
//  Created by Alejandro Cosain on 02/02/24.
//

import Fluent
import Vapor

final class ModelMLDatabasePivot: Model, Content {
    static let schema = "modelml_database_pivot"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "modelml_id")
    var modelML: ModelML
    
    @Parent(key: "database_id")
    var database: DatabaseKelpel
    
    @Field(key: "to_validate")
    var toValidate: Int
    
    @Field(key: "validated")
    var validated: Int
    
    init() {}
    
    init(id: UUID? = nil, modelML: ModelML, database: DatabaseKelpel) throws {
        self.id = id
        self.$modelML.id = try modelML.requireID()
        self.$database.id = try database.requireID()
        self.toValidate = 1
        self.validated = 0
    }
    
    
    struct Public: Content {
        let id: UUID
        let modelML: ModelML.ViewPivot
        let database: DatabaseKelpel.Public
        let toValidate: Int
        let validated: Int
     
    }
    
    
}

extension ModelMLDatabasePivot {
    func asPublic() throws -> Public {
        return Public(id: try requireID(), modelML: try modelML.asViewPublic(), database: try database.asPublic(), toValidate: toValidate, validated: validated)
    }
}
    
    



