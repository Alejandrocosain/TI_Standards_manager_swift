



import Fluent
import Vapor

final class ModelMLPlatformPivot: Model, Content {
    static let schema = "modelml_platform_pivot"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "modelml_id")
    var modelML: ModelML
    
    @Parent(key: "platform_id")
    var platform: Platform

    @Field(key: "to_validate")
    var toValidate: Int
    
    @Field(key: "validated")
    var validated: Int
    
    init() {}
    
    init(id: UUID? = nil, modelML: ModelML, platform: Platform) throws {
        self.id = id
        self.$modelML.id = try modelML.requireID()
        self.$platform.id = try platform.requireID()
        self.toValidate = 1
        self.validated = 0
    }
    
    struct Public: Content {
        let id: UUID
        let modelML: ModelML.ViewPivot
        let platform: Platform.Public
        let toValidate: Int
        let validated: Int
     
    }
    
    
}

extension ModelMLPlatformPivot {
    func asPublic() throws -> Public {
        return Public(id: try requireID(), modelML: try modelML.asViewPublic(), platform: try platform.asPublic(), toValidate: toValidate, validated: validated)
    }
}
