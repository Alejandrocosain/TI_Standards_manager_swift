//
//  File.swift
//  
//
//  Created by Alejandro Cosain on 02/02/24.
//

import Vapor
import Fluent


final class Standard: Model,Content {
    static let schema = "standard"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "type")
    var type: String
    
    @Field(key: "description")
    var description: String
    
    init() {}
    
    init(id: UUID? = nil, name: String, type: String, description: String) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
    }
    
    
}
