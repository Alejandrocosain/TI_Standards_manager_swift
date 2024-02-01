//
//  File.swift
//  
//
//  Created by Alejandro Cosain on 02/02/24.
//

import Fluent
import Vapor

final class PlatformCodeLangPivot: Model, Content {
    static let schema = "platform_codelang_pivot"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "platform_id")
    var platform: Platform
    
    @Parent(key: "codelang_id")
    var codeLang: CodeLang
    
    init() {}
    
    init(id: UUID? = nil, platform: Platform, codeLang: CodeLang) throws {
        self.id = id
        self.$platform.id = try platform.requireID()
        self.$codeLang.id = try codeLang.requireID()
    }
    
}
