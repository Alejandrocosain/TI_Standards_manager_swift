//
//  File.swift
//
//
//  Created by Alejandro Cosain on 02/02/24.
//

import Fluent
import Vapor

final class ModelMLStandardPivot: Model, Content {
    static let schema = "modelml_standard_pivot"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "modelml_id")
    var modelML: ModelML
    
    @Parent(key: "standard_id")
    var standard: Standard
    
    @Field(key: "validated")
    var validated: Int
    
    @Field(key: "to_validate")
    var toValidate: Int
    
    init() {}
    
    init(id: UUID? = nil, modelML: ModelML, standard: Standard) throws {
        self.id = id
        self.$modelML.id = try modelML.requireID()
        self.$standard.id = try standard.requireID()
        self.validated = 0
        self.toValidate = 1
    }
    
    struct Public: Content {
        let id: UUID
        let modelML: ModelML.ViewPivot
        let standard: Standard
        let validated: Int
        let toValidate: Int
    }
    
}
extension ModelMLStandardPivot {
    func asPublic() throws -> Public{
        return Public(id: try requireID(), modelML: try modelML.asViewPublic(), standard: standard, validated: validated, toValidate: toValidate)
    }
}
