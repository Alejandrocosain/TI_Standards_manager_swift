//
//  File.swift
//
//
//  Created by Alejandro Cosain on 03/11/23.
//

import Fluent
import Vapor


final class Token: Model {
    
    static let schema = "tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "value")
    var value: String
    
    @Field(key: "expires_at")
    var expiresAt: Date?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init(){}
    
    init(id: UUID? = nil, userId: User.IDValue, value: String, expiresAt: Date? ) {
        self.id = id
        self.$user.id = userId
        self.value = value
        self.expiresAt = expiresAt
        
    }
    
}


extension Token: ModelTokenAuthenticatable {
    
    static let valueKey = \Token.$value
    static let userKey = \Token.$user
    
    var isValid: Bool{
        guard let expiryDate = expiresAt else {
            return true
        }
        
        return expiryDate > Date()
    }
    
}
