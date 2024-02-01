//
//  File.swift
//  
//
//  Created by Alejandro Cosain on 02/02/24.
//

import Fluent
import Vapor

final class TableKelpel: Model, Content {
    static let schema = "tables"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "description")
    var description: String
    
    @OptionalParent(key: "database")
    var database: DatabaseKelpel?
    
    init() {}
    
    init(id: UUID? = nil, name: String, description: String, databaseID: DatabaseKelpel.IDValue?) {
        self.id = id
        self.name = name
        self.description = description
        self.$database.id = databaseID
    }
    
    
}
