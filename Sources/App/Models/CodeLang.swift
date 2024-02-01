//
//  File.swift
//  
//
//  Created by Alejandro Cosain on 02/02/24.
//

import Vapor
import Fluent

final class CodeLang: Model, Content {
    static let schema = "codelangs"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "type")
    var type: String
    
    init() {}

    init(id: UUID? = nil, name: String, type: String) {
        self.id = id
        self.name = name
        self.type = type
    }
    
    
}
