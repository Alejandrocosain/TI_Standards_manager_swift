import Fluent
import Vapor



struct UserSignup: Content {
    
    let username: String
    let password: String
    let role: String
    let fullName: String
    let employeeId: Int
    let job: String
    
}


extension UserSignup: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("username", as: String.self, is: !.empty)
        validations.add("password", as: String.self, is: .count(6...))
    }

}

struct NewSession: Content {
    
    let token: String
    let user: User.Public
    
}

struct UserController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let userRoute = routes.grouped("user")

        userRoute.post("usersignup", use: create)
        
        let tokenProtected = userRoute.grouped(Token.authenticator())
        let passwordProtected = userRoute.grouped(User.authenticator())
        
        passwordProtected.post("login", use: login)
        tokenProtected.delete("logout", use: logout)
        tokenProtected.get("getall", use: getAllUsers)
        tokenProtected.get("getroles",":roles" ,use: getUsersRoles)
        
    }
    
    func checkIfUserExists(_ username: String, req: Request) -> EventLoopFuture<Bool> {
        User.query(on: req.db)
            .filter(\.$username == username).first()
            .map{$0 != nil}
        
    }

    
    func getAllUsers(req:Request) throws -> EventLoopFuture<[User.Public]> {
        let user = try req.auth.require(User.self)

        return User.query(on: req.db)
            .filter(\.$role != .user)
            .all()
            .flatMapThrowing{
                user in
                let userPublic = try user.map({try $0.asPublic()})
                return userPublic
            }

    }
    
    func getUsersRoles(req:Request) throws -> EventLoopFuture<[User.Public]> {
        let user = try req.auth.require(User.self)
        
        guard let roles = req.parameters.get("roles", as: String.self) else {
            throw Abort(.badRequest)
        }
        print(roles)
        
        let listRoles = roles.components(separatedBy: "_")
        print(listRoles)
        
        let enumRoles = listRoles.map({Roles.withLabel($0)!})
    
        return User.query(on: req.db)
            .filter(\.$role ~~ enumRoles)
            .all()
            .flatMapThrowing{
                user in
                let userPublic = try user.map({try $0.asPublic()})
                return userPublic
            }

    }
    
    func create(req: Request) throws -> EventLoopFuture<NewSession> {
        try UserSignup.validate(content: req)
        
        let userSignup = try req.content.decode(UserSignup.self)
        
        var userRole = Roles.withLabel(userSignup.role)!
            
        
       
        print(userSignup)
        let user = User(username: userSignup.username, passwordHash: try Bcrypt.hash( userSignup.password), role: userRole, fullName: userSignup.fullName, employeeId: userSignup.employeeId, job: userSignup.job)
        
        var token: Token!
        
        return checkIfUserExists(userSignup.username, req: req).flatMap {
            
            exists in
            guard exists == false else {
                return req.eventLoop.future(error: UserError.userNameTaken)
            }
            
            return user.save(on: req.db)
        }.flatMap{
            guard let newToken = try? user.createToken() else {
                return req.eventLoop.future(error:Abort(.internalServerError))
            }
            token = newToken
                                            
            return token.save(on: req.db)
                                            
        }.flatMapThrowing{
            return NewSession(token: token.value, user: try user.asPublic())
        }
  
    }
    
    
    func login(req:Request) throws -> EventLoopFuture<NewSession> {
        let user = try req.auth.require(User.self)
        let token = try user.createToken()
        
        Token.query(on: req.db).filter(\.$user.$id == user.id!).delete()
        return token.save(on: req.db).flatMapThrowing{
            return NewSession(token: token.value, user: try user.asPublic())
        }
        
    }
    
    
    func logout(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
        Token.query(on: req.db).filter(\.$user.$id == user.id!).delete()

        return req.eventLoop.makeSucceededFuture(.ok)
    }

    
    
}


enum UserError {
    case userNameTaken
}

extension UserError: AbortError {
    var description: String {
        reason
    }
    var status: HTTPResponseStatus{
        switch self{
        case .userNameTaken:
            return .conflict
        }
        
    }
    var reason: String {
        switch self {
        case .userNameTaken:
            return "username already taken"
        }
    }
    
}
