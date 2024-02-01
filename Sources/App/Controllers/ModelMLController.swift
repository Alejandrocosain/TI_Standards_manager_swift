//
//  File.swift
//
//
//  Created by Alejandro Cosain on 15/02/24.
//

import Foundation
import Fluent
import Vapor

struct NewModelML: Content {
    
    let name: String
    let ownerID: UUID
    let description: String
    let status: String
}

struct NewVersion: Content {
    let version: Int
}

struct ModelMLController: RouteCollection {
    
    func boot(routes: Vapor.RoutesBuilder) throws {
        let modelMLRoute = routes.grouped("modelml")
        let tokenProtected = modelMLRoute.grouped(Token.authenticator())
        
        tokenProtected.post("register", use: registerMLModel)
        tokenProtected.delete("delete",":modelmlid", use: deleteMLModel)
        tokenProtected.put("request","platform",":modelmlid",":platformid",use: attachPlatformPetition)
        tokenProtected.put("accept","platform",":modelmlid",":platformid",use: acceptPlatformPetition)
        tokenProtected.put("reject","platform",":modelmlid",":platformid",use: rejectPlatformPetition)
        tokenProtected.put("remove","platform",":modelmlid",":platformid",use: deAttachPlatform)
        tokenProtected.put("request","database",":modelmlid",":databaseid",use: attachDatabasePetition)
        tokenProtected.put("accept","database",":modelmlid",":databaseid",use: acceptDatabasePetition)
        tokenProtected.put("reject","database",":modelmlid",":databaseid",use: rejectDatabasePetition)
        tokenProtected.put("remove","database",":modelmlid",":databaseid",use: deAttachDatabase)
        tokenProtected.get("all", use: getAllModelML)
        tokenProtected.put("register","standard",":modelmlid",":standardid", use:attachStandard)
        tokenProtected.put("remove","standard",":modelmlid",":standardid", use:deleteStandard)
        tokenProtected.put("validatepetition","standard",":modelmlid",":standardid",use:validateStandardPetition)
        tokenProtected.put("acceptpetition","standard",":modelmlid",":standardid",use:acceptValidateStandardPetition)
        tokenProtected.put("rejectpetition","standard",":modelmlid",":standardid",use:rejectValidateStandardPetition)
        tokenProtected.put("unvalidate","standard",":modelmlid",":standardid",use:unvalidateStandard)
        tokenProtected.get("standardrequest",use:getStandardsToValidateForModelUser)
        tokenProtected.get("standardrequestadmin",use:getStandardsToValidateForModelAdmin)

        tokenProtected.get("usermodels", use:getUserModelML)
        tokenProtected.get("standards",":modelmlid", use:getStandardsStatusForModel)

        tokenProtected.get(":modelmlid",use:getSpecificModelML)


        tokenProtected.put("deploy",":modelmlid",use: deployModel)
    }
    
    func registerMLModel(req: Request) throws -> EventLoopFuture<ModelML.Public> {
    
        let user = try req.auth.require(User.self)
    
        let userPermits: [Roles] = [.administrator,.scientistSr]
        
        let grantedAccessUsersPermits: [Roles] = [.administrator,.scientistSr,.scientist]

        let newModelML = try req.content.decode(NewModelML.self)
        
        var storeModelML: ModelML!
        
        let modelQuery = ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$modelCreator)
            .filter(\.$name == newModelML.name)
            .first()
        
        let ownerQuery = User.query(on: req.db)
            .filter(\.$id == newModelML.ownerID)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return modelQuery.and(ownerQuery)
            .flatMap{
                model, owner in
                guard model == nil, userPermits.contains(user.role),  grantedAccessUsersPermits.contains(owner.role) else {
                    return req.eventLoop.future(error:ModelMLError.modelMLAlreadyExists)
                }
                
                storeModelML = ModelML(name:newModelML.name , ownerID: newModelML.ownerID, description: newModelML.description, latestVersionValidated: 0,status:newModelML.status, modelCreatorID: user.id!)


                return storeModelML.save(on: req.db)
            }.flatMap{
                return ModelML.query(on: req.db)
                    .with(\.$owner)
                    .with(\.$platforms)
                    .with(\.$databases)
                    .with(\.$standards)
                    .with(\.$modelCreator)
                    .filter(\.$name == storeModelML.name)
                    .first()
                    .unwrap(or: Abort(.notFound))
            }.flatMapThrowing {
                return try $0.asPublic()
            }
    }
    
    
    func getUserModelML(req:Request) throws -> EventLoopFuture<[ModelML.Public]> {
        
        let user = try req.auth.require(User.self)
        
        return ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$platforms){
                platform in
                platform.with(\.$codeLangs)
                    .with(\.$platAdmin)
                    .with(\.$platformCreator)
            }
            .with(\.$databases){
                database in
                database.with(\.$dbAdmin)
                    .with(\.$tables)
                    .with(\.$creatorUser)
            }
            .with(\.$standards)
            .with(\.$modelCreator)
            .group(.or){
                group in
                group.filter(\.$owner.$id == user.id!).filter(\.$modelCreator.$id == user.id!)
            }
            .all()
            .flatMapThrowing{
                modelML in
                let modelMLPublic = try modelML.map({try $0.asPublic()})
                
                return modelMLPublic
            }
    
        
    }

    
    
    
    
    func deleteMLModel(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let admin = try req.auth.require(User.self)
        
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        return ModelML.query(on: req.db)
            .filter(\.$id == modelMLId)
            .with(\.$owner)
            .with(\.$modelCreator)
            .first()
            .flatMap{
                modelML in
                guard modelML != nil, admin.role == .administrator || admin.id == modelML?.modelCreator.id else {
                    return req.eventLoop.future(error:ModelMLError.modelMLDoesNotExists)
                }
                
                return ModelML.query(on: req.db)
                    .filter(\.$id == modelMLId)
                    .delete()
                
            }.flatMapThrowing{
                return .ok
            }
        
    }

    func attachPlatformPetition(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
        
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self), let platformId = req.parameters.get("platformid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let platformQuery = Platform.query(on: req.db)
            .filter(\.$id == platformId)
            .with(\.$platformCreator)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$platforms)
            .with(\.$modelCreator)
            .filter(\.$id == modelMLId)
            .first()
            .unwrap(or: Abort(.notFound))
            .and(platformQuery)
            .flatMap{
                modelml, platform in
                let attachedPlatforms = modelml.platforms.map{$0.id}
                guard user.role == .administrator || user.id == modelml.modelCreator.id || user.id == modelml.owner.id, !attachedPlatforms.contains(platformId) else {
                    return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
                    
                }
                
                modelml.$platforms.attach(platform, on: req.db){
                    pivot in
                    pivot.toValidate = 1
                    pivot.validated = 0
                    
                }
                return req.eventLoop.makeSucceededFuture(.ok)
            }

    }
    
    
    func acceptPlatformPetition(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
        
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self), let platformId = req.parameters.get("platformid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let platformQuery = Platform.query(on: req.db)
            .filter(\.$id == platformId)
            .with(\.$platAdmin)
            .with(\.$platformCreator)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$platforms)
            .with(\.$modelCreator)
            .filter(\.$id == modelMLId)
            .first()
            .unwrap(or: Abort(.notFound))
            .and(platformQuery)
            .flatMap{
                modelml, platform in
                let attachedPlatforms = modelml.platforms.map{$0.id}
                guard user.role == .administrator || user.id == platform.platformCreator.id || user.id == platform.platAdmin?.id, attachedPlatforms.contains(platformId) else {
                    return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
                    
                }
                return ModelMLPlatformPivot.query(on: req.db)
                    .filter(\.$modelML.$id == modelMLId)
                    .filter(\.$platform.$id == platformId)
                    .set(\.$validated, to: 1)
                    .set(\.$toValidate, to: 0)
                    .update()
                    .eventLoop.makeSucceededFuture(.ok)
          
                
                
            }
        
    }
    
    func rejectPlatformPetition(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
        
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self), let platformId = req.parameters.get("platformid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let platformQuery = Platform.query(on: req.db)
            .filter(\.$id == platformId)
            .with(\.$platAdmin)
            .with(\.$platformCreator)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$platforms)
            .with(\.$modelCreator)
            .filter(\.$id == modelMLId)
            .first()
            .unwrap(or: Abort(.notFound))
            .and(platformQuery)
            .flatMap{
                modelml, platform in
                let attachedPlatforms = modelml.platforms.map{$0.id}
                guard user.role == .administrator || user.id == platform.platformCreator.id || user.id == platform.platAdmin?.id || user.id == modelml.modelCreator.id || user.id == modelml.owner.id, attachedPlatforms.contains(platformId) else {
                    return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
                    
                }
                modelml.$platforms.detach(platform, on: req.db)
                
                return req.eventLoop.makeSucceededFuture(.ok)
          
                
            }
        
    }
    
   
    func deAttachPlatform(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
        
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self), let platformId = req.parameters.get("platformid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let platformQuery = Platform.query(on: req.db)
            .filter(\.$id == platformId)
            .with(\.$platAdmin)
            .with(\.$platformCreator)
            .first()
            .unwrap(or: Abort(.notFound))
        
        
        let modelQuery = ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$platforms)
            .filter(\.$id == modelMLId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return platformQuery.and(modelQuery).flatMap{
            platform, model in
            guard user.role == .administrator || user.id == platform.platformCreator.id || user.id == platform.platAdmin?.id else {
                return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
            }
            
            model.$platforms.detach(platform, on: req.db)
            return req.eventLoop.makeSucceededFuture(.ok)
        }
         

    }
  
    
    
    
    
    func attachDatabasePetition(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
        
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self), let databaseId = req.parameters.get("databaseid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let databaseQuery = DatabaseKelpel.query(on: req.db)
            .filter(\.$id == databaseId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$platforms)
            .with(\.$databases)
            .with(\.$modelCreator)
            .filter(\.$id == modelMLId)
            .first()
            .unwrap(or: Abort(.notFound))
            .and(databaseQuery)
            .flatMap{
                modelml, database in
                let attacheDatabase = modelml.databases.map{$0.id}
                guard user.role == .administrator || user.id == modelml.modelCreator.id || user.id == modelml.owner.id, !attacheDatabase.contains(databaseId) else {
                    return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
                    
                }
                
                modelml.$databases.attach(database, on: req.db){
                    pivot in
                    pivot.toValidate = 1
                    pivot.validated = 0
                    
                }
                
                
                return req.eventLoop.makeSucceededFuture(.ok)
                
                
            }

    }
    
    
    func acceptDatabasePetition(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
        
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self), let databaseId = req.parameters.get("databaseid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let databaseQuery = DatabaseKelpel.query(on: req.db)
            .filter(\.$id == databaseId)
            .with(\.$creatorUser)
            .with(\.$dbAdmin)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$platforms)
            .with(\.$databases)
            .with(\.$modelCreator)
            .filter(\.$id == modelMLId)
            .first()
            .unwrap(or: Abort(.notFound))
            .and(databaseQuery)
            .flatMap{
                modelml, database in
                let attacheDatabases = modelml.databases.map{$0.id}
                guard user.role == .administrator || user.id == database.creatorUser.id || user.id == database.dbAdmin?.id, attacheDatabases.contains(databaseId) else {
                    return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
                    
                }
                return ModelMLDatabasePivot.query(on: req.db)
                    .filter(\.$modelML.$id == modelMLId)
                    .filter(\.$database.$id == databaseId)
                    .set(\.$validated, to: 1)
                    .set(\.$toValidate, to: 0)
                    .update()
                    .eventLoop.makeSucceededFuture(.ok)
          
            }
        
    }
    
    func rejectDatabasePetition(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
        
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self), let databaseId = req.parameters.get("databaseid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let databaseQuery = DatabaseKelpel.query(on: req.db)
            .filter(\.$id == databaseId)
            .with(\.$creatorUser)
            .with(\.$dbAdmin)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$platforms)
            .with(\.$databases)
            .with(\.$modelCreator)
            .filter(\.$id == modelMLId)
            .first()
            .unwrap(or: Abort(.notFound))
            .and(databaseQuery)
            .flatMap{
                modelml, database in
                let attacheDatabases = modelml.databases.map{$0.id}
                guard user.role == .administrator || user.id == database.creatorUser.id || user.id == database.dbAdmin?.id, attacheDatabases.contains(databaseId) else {
                    return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
                    
                }
                modelml.$databases.detach(database, on: req.db)
                
                return req.eventLoop.makeSucceededFuture(.ok)
          
                
            }
        
    }
    
    
    func deAttachDatabase(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
        
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self), let databaseId = req.parameters.get("databaseid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let databaseQuery = DatabaseKelpel.query(on: req.db)
            .filter(\.$id == databaseId)
            .with(\.$creatorUser)
            .with(\.$dbAdmin)
            .first()
            .unwrap(or: Abort(.notFound))
        
        
        let modelQuery =  ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$platforms)
            .with(\.$databases)
            .with(\.$modelCreator)
            .filter(\.$id == modelMLId)
            .first()
            .unwrap(or: Abort(.notFound))
            
        return databaseQuery.and(modelQuery).flatMap{
            database, model in
            guard user.role == .administrator || user.id == database.creatorUser.id || user.id == database.dbAdmin?.id else {
                return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
            }
            
            model.$databases.detach(database, on: req.db)
            return req.eventLoop.makeSucceededFuture(.ok)
        }

    }
    
    
    
    func getAllModelML(req: Request) throws -> EventLoopFuture<[ModelML.Public]> {
        let user = try req.auth.require(User.self)

        return ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$platforms){
                platform in
                platform.with(\.$codeLangs)
                    .with(\.$platAdmin)
                    .with(\.$platformCreator)
            }
            .with(\.$databases){
                database in
                database.with(\.$dbAdmin)
                    .with(\.$tables)
                    .with(\.$creatorUser)
            }
            .with(\.$standards)
            .with(\.$modelCreator)
            .all()
            .flatMapThrowing{
                return try $0.map({try $0.asPublic()})
            }
        
        
    }
    
    
    func getStandardsStatusForModel(req: Request) throws -> EventLoopFuture<[ModelMLStandardPivot]> {
        let user = try req.auth.require(User.self)

        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        return ModelMLStandardPivot.query(on: req.db)
            .filter(\.$modelML.$id == modelMLId)
            .all()
    }
    
    func getStandardsToValidateForModelUser(req: Request) throws -> EventLoopFuture<[ModelMLStandardPivot.Public]> {
        let user = try req.auth.require(User.self)
        
        return ModelML.query(on: req.db)
            .with(\.$modelCreator)
            .with(\.$owner)
            .filter(\.$modelCreator.$id == user.id! )
            .all()
            .flatMap {
                models -> EventLoopFuture<[ModelMLStandardPivot]> in
                let modelsId = models.map({$0.id!})
                return ModelMLStandardPivot.query(on: req.db)
                    .with(\.$modelML)
                    .with(\.$standard)
                    .filter(\.$toValidate == 1)
                    .filter(\.$validated == 0)
                    .filter(\.$modelML.$id ~~ modelsId)
                    .all()
                
                
            }.flatMapThrowing {
                pivots  in
                return try pivots.map({try $0.asPublic()})
            }
    }
    
    func getStandardsToValidateForModelAdmin(req: Request) throws -> EventLoopFuture<[ModelMLStandardPivot.Public]> {
        let user = try req.auth.require(User.self)
        
        guard user.role == .administrator else {
            throw Abort(.badRequest)
        }
        
        return ModelML.query(on: req.db)
            .with(\.$modelCreator)
            .with(\.$owner)
            .all()
            .flatMap {
                models -> EventLoopFuture<[ModelMLStandardPivot]> in
                let modelsId = models.map({$0.id!})
                return ModelMLStandardPivot.query(on: req.db)
                    .with(\.$modelML)
                    .with(\.$standard)
                    .filter(\.$toValidate == 1)
                    .filter(\.$validated == 0)
                    .all()
                
                
            }.flatMapThrowing {
                pivots  in
                return try pivots.map({try $0.asPublic()})
            }
    }

    func getSpecificModelML(req: Request) throws -> EventLoopFuture<ModelML.Public> {
        let user = try req.auth.require(User.self)

        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        return ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$platforms){
                platform in
                platform.with(\.$codeLangs)
                    .with(\.$platAdmin)
                    .with(\.$platformCreator)
            }
            .with(\.$databases){
                database in
                database.with(\.$dbAdmin)
                    .with(\.$tables)
                    .with(\.$creatorUser)
            }
            .with(\.$standards)
            .with(\.$modelCreator)
            .filter(\.$id == modelMLId)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing{
                mlModelResult in
                return try mlModelResult.asPublic()
            }
        
        
        
    }
    
    func attachStandard(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)

        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self), let standardId = req.parameters.get("standardid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let modelQuery = ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$databases)
            .with(\.$platforms)
            .with(\.$standards)
            .with(\.$modelCreator)
            .filter(\.$id == modelMLId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        let standardQuery = Standard.query(on: req.db)
            .filter(\.$id == standardId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        
        return modelQuery.and(standardQuery).flatMap{
            model, standard -> EventLoopFuture<ModelML> in
            guard model.modelCreator.id == user.id || user.role == .administrator else {
                return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
            }
            
            model.$standards.attach(standard, on: req.db){
                pivot in
                pivot.validated = 0
                pivot.toValidate = 0
            }
            return ModelML.query(on: req.db)
                .filter(\.$id == modelMLId)
                .first()
                .unwrap(or: Abort(.notFound))
        }.flatMap{
            model in
            if model.latestVersionValidated == 0 {
                return ModelML.query(on: req.db)
                    .filter(\.$id == modelMLId)
                    .set(\.$status, to:"Nuevo modelo en desarrollo")
                    .update()
            } else {
                return ModelML.query(on: req.db)
                    .filter(\.$id == modelMLId)
                    .set(\.$status, to:"Modelo en actualización")
                    .update()
            }
        }.flatMapThrowing{
            return .ok
        }
        
    }
    
    
    func deleteStandard(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)

        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self), let standardId = req.parameters.get("standardid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let modelQuery = ModelML.query(on: req.db)
            .with(\.$owner)
            .with(\.$databases)
            .with(\.$platforms)
            .with(\.$standards)
            .with(\.$modelCreator)
            .filter(\.$id == modelMLId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        let standardQuery = Standard.query(on: req.db)
            .filter(\.$id == standardId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        
        return modelQuery.and(standardQuery).flatMap{
            model, standard -> EventLoopFuture<[ModelMLStandardPivot]> in
            guard model.modelCreator.id == user.id || user.role == .administrator else {
                return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
            }
            
            model.$standards.detach(standard, on: req.db)
            return ModelMLStandardPivot.query(on: req.db)
                .filter(\.$modelML.$id == modelMLId)
                .all()
        }.flatMap {
            pivots in
            let pivots_validated = pivots.filter({$0.validated == 1})
            if pivots.count == pivots_validated.count{
                return ModelML.query(on: req.db)
                    .filter(\.$id == modelMLId)
                    .set(\.$status, to: "Listo para desplegar").update()
                    .flatMapThrowing{
                        return .ok
                    }
            } else {
                return req.eventLoop.makeSucceededFuture(.ok)
            }
        }
        
    }
    
    func validateStandardPetition(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
       
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self),let standardID = req.parameters.get("standardid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
         
        let modelMLQuery = ModelML.query(on:req.db)
            .filter(\.$id == modelMLId)
            .with(\.$modelCreator)
            .with(\.$owner)
            .first()
            .unwrap(or: Abort(.notFound))
       
        let standardQuery = Standard.query(on:req.db)
            .filter(\.$id == standardID)
            .first()
            .unwrap(or: Abort(.notFound))
       
        return modelMLQuery.and(standardQuery).flatMap{
            model, standard in
            guard model.owner.id == user.id || model.modelCreator.id == user.id || user.role == .administrator else {
                return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
            }
            return ModelMLStandardPivot.query(on: req.db)
                .filter(\.$modelML.$id == modelMLId)
                .filter(\.$standard.$id == standardID)
                .set(\.$toValidate, to: 1)
                .update()
                .eventLoop.makeSucceededFuture(.ok)
        }
    
        
    }
    
    
    
    func acceptValidateStandardPetition(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
       
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self),let standardID = req.parameters.get("standardid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
         
        let modelMLQuery = ModelML.query(on:req.db)
            .filter(\.$id == modelMLId)
            .with(\.$modelCreator)
            .with(\.$owner)
            .with(\.$standards)
            .with(\.$standards.$pivots) {
                pivot in
                pivot.with(\.$standard)
            }
            .first()
            .unwrap(or: Abort(.notFound))
       
        let standardQuery = Standard.query(on:req.db)
            .filter(\.$id == standardID)
            .first()
            .unwrap(or: Abort(.notFound))
       
        return modelMLQuery.and(standardQuery).flatMap{
            model, standard in
            guard let standardToValidate = model.$standards.pivots.filter({$0.standard.id == standardID}).first, standardToValidate.toValidate == 1, model.modelCreator.id == user.id || user.role == .administrator else {
                return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
            }
            return ModelMLStandardPivot.query(on: req.db)
                .filter(\.$modelML.$id == modelMLId)
                .filter(\.$standard.$id == standardID)
                .set(\.$validated, to: 1)
                .set(\.$toValidate, to: 0)
                .update()
        }.flatMap{
            return ModelMLStandardPivot.query(on: req.db)
                .filter(\.$modelML.$id == modelMLId)
                .all()
        }.flatMap {
            pivots in
            let pivots_validated = pivots.filter({$0.validated == 1})
            if pivots.count == pivots_validated.count{
                return ModelML.query(on: req.db)
                    .filter(\.$id == modelMLId)
                    .set(\.$status, to: "Listo para desplegar").update()
                    .flatMapThrowing{
                        return .ok
                    }
            } else {
                return req.eventLoop.makeSucceededFuture(.ok)
            }
        }
    
        
    }
    
    func rejectValidateStandardPetition(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
       
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self),let standardID = req.parameters.get("standardid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
         
        let modelMLQuery = ModelML.query(on:req.db)
            .filter(\.$id == modelMLId)
            .with(\.$modelCreator)
            .with(\.$owner)
            .with(\.$standards)
            .with(\.$standards.$pivots){
                pivot in
                pivot.with(\.$standard)
            }
            .first()
            .unwrap(or: Abort(.notFound))
       
        let standardQuery = Standard.query(on:req.db)
            .filter(\.$id == standardID)
            .first()
            .unwrap(or: Abort(.notFound))
       
        return modelMLQuery.and(standardQuery).flatMap{
            model, standard in
            guard let standardToValidate = model.$standards.pivots.filter({$0.standard.id == standardID}).first, standardToValidate.toValidate == 1, model.modelCreator.id == user.id || user.role == .administrator else {
                return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
            }
            return ModelMLStandardPivot.query(on: req.db)
                .filter(\.$modelML.$id == modelMLId)
                .filter(\.$standard.$id == standardID)
                .set(\.$toValidate, to: 0)
                .update()
                .eventLoop.makeSucceededFuture(.ok)
        }
    
        
    }
    
    func unvalidateStandard(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
       
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self),let standardID = req.parameters.get("standardid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
         
        let modelMLQuery = ModelML.query(on:req.db)
            .filter(\.$id == modelMLId)
            .with(\.$modelCreator)
            .with(\.$owner)
            .with(\.$standards)
            .with(\.$standards.$pivots){
                pivot in
                pivot.with(\.$standard)
            }
            .first()
            .unwrap(or: Abort(.notFound))
       
        let standardQuery = Standard.query(on:req.db)
            .filter(\.$id == standardID)
            .first()
            .unwrap(or: Abort(.notFound))
       
        return modelMLQuery.and(standardQuery).flatMap{
            model, standard in
            guard let standardToValidate = model.$standards.pivots.filter({$0.standard.id == standardID}).first, standardToValidate.validated == 1, model.modelCreator.id == user.id || user.role == .administrator else {
                return req.eventLoop.future(error: ModelMLError.cannotModifyMLModel)
            }
            return ModelMLStandardPivot.query(on: req.db)
                .filter(\.$modelML.$id == modelMLId)
                .filter(\.$standard.$id == standardID)
                .set(\.$validated, to: 0)
                .update()
        }.flatMap{
            return ModelMLStandardPivot.query(on: req.db)
                .filter(\.$modelML.$id == modelMLId)
                .all()
        }.flatMap {
            pivots in
            let pivots_validated = pivots.filter({$0.validated == 1})
            if pivots.count == pivots_validated.count{
                return ModelML.query(on: req.db)
                    .filter(\.$id == modelMLId)
                    .set(\.$status, to: "Listo para desplegar").update()
                    .flatMapThrowing{
                        return .ok
                    }
            } else {
                return req.eventLoop.makeSucceededFuture(.ok)
            }
        }
    
        
    }
    
    func deployModel(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let user = try req.auth.require(User.self)
       
        guard let modelMLId = req.parameters.get("modelmlid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        let modelMLQuery = ModelML.query(on:req.db)
            .filter(\.$id == modelMLId)
            .filter(\.$status == "Listo para desplegar")
            .first()
            .unwrap(or: Abort(.notFound))
       
       
        return modelMLQuery.flatMap{
            model in
            return ModelML.query(on: req.db)
                .filter(\.$id == modelMLId)
                .set(\.$status, to: "Desplegado")
                .set(\.$latestVersionValidated, to: model.latestVersionValidated+1)
                .update()
        }.flatMapThrowing{
            return .ok
        }
        
    }
 
    
}

enum ModelMLError {
    case modelMLAlreadyExists
    case modelMLDoesNotExists
    case cannotModifyMLModel

}

extension ModelMLError: AbortError {
    var description: String {
        reason
    }
    var status: HTTPResponseStatus{
        switch self{
        case .modelMLAlreadyExists:
            return .conflict
        case .modelMLDoesNotExists:
            return .conflict
        case .cannotModifyMLModel:
            return .conflict
            
        }
        
    }
    var reason: String {
        switch self {
        case .modelMLAlreadyExists:
            return "Machine learning model already exists"
        case .modelMLDoesNotExists:
            return "Machine learning model does not exists"
        case .cannotModifyMLModel:
            return "You dont have rights to modify this model"
            
        }
    }
}
