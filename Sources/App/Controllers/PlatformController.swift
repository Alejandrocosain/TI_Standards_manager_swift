//
//  File.swift
//  
//
//  Created by Alejandro Cosain on 15/02/24.
//

import Foundation
import Fluent
import Vapor

struct NewPlatform: Content {
    
    let name: String
    let ip: String
    let description: String
    
}

struct PlatformController: RouteCollection {
    
    func boot(routes: Vapor.RoutesBuilder) throws {
        let platformRoute = routes.grouped("platform")
        let tokenProtected = platformRoute.grouped(Token.authenticator())
        
        tokenProtected.post("register", use: registerPlatform)
        tokenProtected.put("register","platadmin",":userid",":platformid", use:registerPA)
        tokenProtected.put("remove","platadmin",":userid",":platformid", use:removePA)
        tokenProtected.delete("delete",":platformid",use: deletePlatform)
        tokenProtected.put("register","codelang",":platformid",":codelangid", use: assignCodeLang)
        tokenProtected.put("remove","codelang",":platformid",":codelangid", use: removeCodeLang)
        tokenProtected.get("all", use: getAllPlatforms)
        tokenProtected.get("userplatforms", use:getUserPlatform)
        tokenProtected.get(":platformid", use:getPlatform)
        tokenProtected.get(":platformid","allmodels", use: getModelsFromPlatforms)
        tokenProtected.get("requests",use:getPlatformsAssignmentsRequest)
        tokenProtected.get("requests","admin",use:getPlatformsAssignmentsRequestAdmin)

    }
    
    func registerPlatform(req: Request) throws -> EventLoopFuture<Platform.Public> {
    
        let user = try req.auth.require(User.self)
    
        let userPermits: [Roles] = [.administrator,.architectSr]

        let newPlatform = try req.content.decode(NewPlatform.self)
        
        var storePlatform: Platform!
        
        return Platform.query(on: req.db)
            .filter(\.$name == newPlatform.name)
            .first()
            .flatMap{
                queryResult in
                guard queryResult == nil, userPermits.contains(user.role) else {
                    return req.eventLoop.future(error:PlatformError.platformAlreadyExists)
                }
                
                storePlatform = Platform(name: newPlatform.name, ip: newPlatform.ip, description: newPlatform.description, platformCreatorID: user.id!)
                return storePlatform.save(on: req.db)
            }.flatMap{
                return Platform.query(on: req.db)
                    .filter(\.$name == storePlatform.name)
                    .filter(\.$ip == storePlatform.ip)
                    .with(\.$platAdmin)
                    .with(\.$codeLangs)
                    .with(\.$platformCreator)
                    .first()
                    .unwrap(or: Abort(.notFound))
                
            }.flatMapThrowing{
                return try $0.asPublic()
            }
       
    }
    
    func registerPA(req: Request) throws -> EventLoopFuture<HTTPStatus>
    {
        let admin = try req.auth.require(User.self)
        let userPermits: [Roles] = [.administrator,.architectSr,.architect]
        
        guard let userId = req.parameters.get("userid", as: UUID.self), let platformId = req.parameters.get("platformid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let userQuery = User.query(on: req.db)
            .filter(\.$id == userId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        let platformQuery = Platform.query(on: req.db)
            .with(\.$platAdmin)
            .filter(\.$id == platformId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return userQuery.and(platformQuery)
            .flatMap{
                user, platform in
                guard userPermits.contains(user.role),admin.role == .administrator || admin.id == platform.platformCreator.id, platform.platAdmin == nil else {
                    return req.eventLoop.future(error: PlatformError.cantGrantPermissions)
                }
                return Platform.query(on: req.db)
                    .filter(\.$id == platformId)
                    .set(\.$platAdmin.$id, to: userId)
                    .update()
                
            }.flatMapThrowing{
                return .ok
            }
        
    }
    
    
    func removePA(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let admin = try req.auth.require(User.self)
        
        guard let userId = req.parameters.get("userid", as: UUID.self), let platformId = req.parameters.get("platformid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let userQuery = User.query(on: req.db)
            .filter(\.$id == userId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        let platformQuery = Platform.query(on: req.db)
            .with(\.$platAdmin)
            .filter(\.$id == platformId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return userQuery.and(platformQuery).flatMap{
            user,platform in
            guard user.id == platform.platAdmin?.id, admin.role == .administrator || admin.id == platform.platformCreator.id  else {
              return req.eventLoop.future(error: PlatformError.incorrectUser)
            }
            
            return Platform.query(on: req.db)
                .filter(\.$id == platformId)
                .set(\.$platAdmin.$id, to: nil)
                .update()
            
        }.flatMapThrowing{
            return .ok
        }
        
    }
    
    func deletePlatform(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let admin = try req.auth.require(User.self)
        
        guard let platformId = req.parameters.get("platformid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let platformQuery = Platform.query(on: req.db)
            .with(\.$platAdmin)
            .filter(\.$id == platformId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return platformQuery.flatMap{
            platform in
            guard platform.platAdmin == nil ,admin.role == .administrator || admin.id == platform.platformCreator.id else {
                return req.eventLoop.future(error: PlatformError.cantErasePlatform)
            }
            
            return Platform.query(on: req.db)
                .filter(\.$id == platformId)
                .delete()
                
        }.flatMapThrowing{
            return .ok
        }
        
    }
    
    
    func assignCodeLang(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let admin = try req.auth.require(User.self)
        
        guard let platformId = req.parameters.get("platformid", as: UUID.self), let codeLangId = req.parameters.get("codelangid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let codeLangQuery = CodeLang.query(on: req.db)
            .filter(\.$id == codeLangId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        let platformQuery = Platform.query(on: req.db)
            .with(\.$codeLangs)
            .with(\.$platAdmin)
            .filter(\.$id == platformId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return codeLangQuery.and(platformQuery).flatMap{
            codeLang, platform in
            let codeLangsIds = platform.codeLangs.map({$0.id})
            guard platform.platAdmin?.id == admin.id || admin.role == .administrator || admin.id == platform.platformCreator.id, !codeLangsIds.contains(codeLangId) else {
                return req.eventLoop.future(error: PlatformError.cantAssignCodeLang)
            }
            
            platform.$codeLangs.attach(codeLang, on: req.db )
            
            return req.eventLoop.makeSucceededFuture(.ok)
            
        }
        
        
    }
    
    func getAllPlatforms(req:Request) throws -> EventLoopFuture< [Platform.Public]>{
        let user = try req.auth.require(User.self)
        
        return Platform.query(on:req.db)
            .with(\.$codeLangs)
            .with(\.$platAdmin)
            .with(\.$platformCreator)
            .all()
            .flatMapThrowing{
                platforms in
                let platformsPublic = try platforms.map({try $0.asPublic()})
                
                return platformsPublic
            }
        
    }
    
    func getPlatform(req:Request) throws -> EventLoopFuture<Platform.Public>{
        let user = try req.auth.require(User.self)
        
        guard let platformId = req.parameters.get("platformid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        return Platform.query(on:req.db)
            .with(\.$codeLangs)
            .with(\.$platAdmin)
            .with(\.$platformCreator)
            .filter(\.$id == platformId)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing{
                platform in
                return try platform.asPublic()
                

            }
        
    }

    
    
    func getUserPlatform(req:Request) throws -> EventLoopFuture<[Platform.Public]> {
        
        let user = try req.auth.require(User.self)
        
        return Platform.query(on: req.db)
            .with(\.$platAdmin)
            .with(\.$codeLangs)
            .with(\.$platformCreator)
            .group(.or){
                group in
                group.filter(\.$platAdmin.$id == user.id).filter(\.$platformCreator.$id == user.id!)
            }
            .all()
            .flatMapThrowing{
                platforms in
                let platformsPublic = try platforms.map({try $0.asPublic()})
                
                return platformsPublic
            }
    
        
    }
    func removeCodeLang(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let admin = try req.auth.require(User.self)
        
        guard let platformId = req.parameters.get("platformid", as: UUID.self), let codeLangId = req.parameters.get("codelangid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let codeLangQuery = CodeLang.query(on: req.db)
            .filter(\.$id == codeLangId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        let platformQuery = Platform.query(on: req.db)
            .with(\.$codeLangs)
            .with(\.$platAdmin)
            .filter(\.$id == platformId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return codeLangQuery.and(platformQuery).flatMap{
            codeLang, platform in
            let codeLangsIds = platform.codeLangs.map({$0.id})
            guard platform.platAdmin?.id == admin.id || admin.role == .administrator || admin.id == platform.platformCreator.id ,codeLangsIds.contains(codeLangId)  else {
                return req.eventLoop.future(error: PlatformError.cantAssignCodeLang)
            }
            
            platform.$codeLangs.detach(codeLang, on: req.db )
            
            return req.eventLoop.makeSucceededFuture(.ok)
            
        }
        
        
    }
    func getModelsFromPlatforms(req:Request) throws -> EventLoopFuture<[ModelML.Public]> {
        
        let user = try req.auth.require(User.self)
        
        guard let platfromID = req.parameters.get("platformid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        
        return ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$platforms){
                platform in
                platform.with(\.$codeLangs)
                    .with(\.$platAdmin)
            }
            .with(\.$databases){
                database in
                database.with(\.$dbAdmin)
                    .with(\.$tables)
            }
            .with(\.$standards)
            .all()
            .flatMapThrowing{
                modelML in
                let filteredModels = modelML.filter({$0.platforms.map({$0.id}).contains(platfromID)})
                let modelMLPublic = try filteredModels.map({try $0.asPublic()})
                
                return modelMLPublic
            }
    
        
    }
    
    func getPlatformsAssignmentsRequest(req:Request) throws -> EventLoopFuture<[ModelMLPlatformPivot.Public]> {
        
        let user = try req.auth.require(User.self)
        
        return Platform.query(on: req.db)
            .with(\.$platAdmin)
            .with(\.$platformCreator)
            .with(\.$codeLangs)

            .group(.or) { group in
                group.filter(\.$platAdmin.$id == user.id! ).filter(\.$platformCreator.$id == user.id! )
            }
            .all()
            .flatMap {
                platforms -> EventLoopFuture<[ModelMLPlatformPivot]> in
                let platformsId = platforms.map({$0.id!})
                return ModelMLPlatformPivot.query(on: req.db)
                    .with(\.$modelML)
                    .with(\.$platform){
                        platform in
                        platform.with(\.$platAdmin)
                            .with(\.$platformCreator)
                            .with(\.$codeLangs)
                    }
                    .filter(\.$platform.$id ~~ platformsId)
                    .filter(\.$toValidate == 1)
                    .filter(\.$validated == 0)
                    .all()
                
                
            }.flatMapThrowing {
                pivots  in
                return try pivots.map({try $0.asPublic()})
            }
    
        
    }
    func getPlatformsAssignmentsRequestAdmin(req:Request) throws -> EventLoopFuture<[ModelMLPlatformPivot.Public]> {
        
        let user = try req.auth.require(User.self)
        
        guard user.role == .administrator else {
            throw Abort(.badRequest)
        }
        
        return Platform.query(on: req.db)
            .with(\.$platAdmin)
            .with(\.$platformCreator)
            .with(\.$codeLangs)
            .all()
            .flatMap {
                platforms -> EventLoopFuture<[ModelMLPlatformPivot]> in
                let platformsId = platforms.map({$0.id!})
                return ModelMLPlatformPivot.query(on: req.db)
                    .with(\.$modelML)
                    .with(\.$platform){
                        platform in
                        platform.with(\.$platAdmin)
                            .with(\.$platformCreator)
                            .with(\.$codeLangs)
                    }
                    .filter(\.$platform.$id ~~ platformsId)
                    .filter(\.$toValidate == 1)
                    .filter(\.$validated == 0)
                    .all()
                
                
            }.flatMapThrowing {
                pivots  in
                return try pivots.map({try $0.asPublic()})
            }
    
        
    }
    
    
    
 
    

}

enum PlatformError {
    case platformAlreadyExists
    case cantGrantPermissions
    case cantCreatePlatform
    case cantErasePlatform
    case incorrectUser
    case cantAssignCodeLang
}

extension PlatformError: AbortError {
    var description: String {
        reason
    }
    var status: HTTPResponseStatus{
        switch self{
        case .platformAlreadyExists:
            return .conflict
        case .cantGrantPermissions:
            return .conflict
        case .cantCreatePlatform:
            return .conflict
        case .cantErasePlatform:
            return .conflict
        case .incorrectUser:
            return .conflict
        case .cantAssignCodeLang:
            return .conflict
        }
        
    }
    var reason: String {
        switch self {
        case .platformAlreadyExists:
            return "Platform already exists"
        case .cantGrantPermissions:
            return "Cannot grant permissions to read-only user"
        case .cantCreatePlatform:
            return "Cannot create platform"
        case .cantErasePlatform:
            return "Cannot erase platform"
        case .incorrectUser:
            return "This user isn´t the platform administrator"
        case .cantAssignCodeLang:
            return "Cannot assign Code language to platform"
        }
    }
    
}


