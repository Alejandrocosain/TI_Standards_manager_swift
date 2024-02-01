import Fluent
import Vapor

final class User: Model, Content {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String
   
    @Field(key: "password_hash")
    var passwordHash: String

    @Enum(key: "role")
    var role: Roles
    
    @Field(key: "full_name")
    var fullName: String
    
    @Field(key: "employee_id")
    var employeeId: Int
    
    @Field(key: "job")
    var job: String
    
    @Timestamp(key: "creation_date", on:.create)
    var creationDate: Date?
    
    @Timestamp(key: "update_date", on: .update)
    var updateDate: Date?
   
    
    init() {}
    init(id: UUID? = nil , username: String, passwordHash: String, role: Roles, fullName: String, employeeId: Int, job: String) {
        self.id = id
        self.username = username
        self.passwordHash = passwordHash
        self.role = role
        self.fullName = fullName
        self.employeeId = employeeId
        self.job = job
  
    }
    
    
    struct Public: Content {
        let username:String
        let role: Roles
        let fullName: String
        let job: String
        let id: UUID
    }
    
    
    
}

extension User {
    func asPublic() throws -> Public {
        return Public(username: username, role: role, fullName: fullName, job: job, id: try requireID())
    }
    
    
    func createToken() throws -> Token {
        let calendar = Calendar(identifier: .gregorian)
        let expiryDate = calendar.date(byAdding: .year, value: 1, to: Date())
        return try Token(userId: try requireID(), value: [UInt8].random(count: 16).base64, expiresAt: expiryDate)
    }
}




extension User: ModelAuthenticatable {
    static let usernameKey = \User.$username
    static let passwordHashKey = \User.$passwordHash
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password,created: self.passwordHash)
    }
    
}

