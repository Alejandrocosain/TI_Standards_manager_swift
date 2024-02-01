//
//  File.swift
//  
//
//  Created by Alejandro Cosain on 08/02/24.
//

import Foundation
import Fluent
import Vapor

struct NewDatabase: Content {
    
    let name: String
    let ip: String
    let description: String
    
}

struct NewTableKelpel: Content {
    let name: String
    let description: String
}

struct DatabaseTableController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let databaseRoute = routes.grouped("database")
        let tokenProtected = databaseRoute.grouped(Token.authenticator())
        tokenProtected.post("register", use: registerDatabase)
        tokenProtected.get("alldatabases", use: getAllDatabase)
        tokenProtected.get(":databaseid", use: getDatabase)
        tokenProtected.put("register","dba",":userid",":databaseid", use:registerDBA)
        tokenProtected.post(":databaseid","registertable", use: registerTable)
        tokenProtected.delete("deletetable",":tableid", use: deleteTable)
        tokenProtected.put("remove","dba", ":userid",":databaseid" ,use:removeDBAdmin)
        tokenProtected.delete("deletedatabase",":databaseid", use: deleteDatabase)
        tokenProtected.get("userdatabase", use:getUserDatabase)
        tokenProtected.get(":databaseid","allmodels",use:getModelsFromDatabase)
        tokenProtected.get("requests",use:getDatabaseAssignmentsRequest)
        tokenProtected.get("requests","admin",use:getDatabaseAssignmentsRequestAdmin)

    }

    func registerDatabase(req: Request) throws -> EventLoopFuture<DatabaseKelpel.Public> {
    
        let user = try req.auth.require(User.self)
    
        let newDatabase = try req.content.decode(NewDatabase.self)
        let userPermits: [Roles] = [.administrator,.engineerSr]
        var storeDatabase: DatabaseKelpel!
        
        return DatabaseKelpel.query(on: req.db)
            .with(\.$dbAdmin)
            .with(\.$tables){
                table in
                table.with(\.$database)
            }
            .with(\.$creatorUser)
            .filter(\.$name == newDatabase.name)
            .first()
            .flatMap{
                queryResult in
                guard queryResult == nil, userPermits.contains(user.role) else {
                    return req.eventLoop.future(error:DatabaseTableError.databaseAlreadyExists)
                }
                
                storeDatabase = DatabaseKelpel(name: newDatabase.name, ip: newDatabase.ip, description: newDatabase.description, creatorUserId: user.id!)
                
                return storeDatabase.save(on: req.db)
            }.flatMap{
                return DatabaseKelpel.query(on: req.db)
                    .filter(\.$name == storeDatabase.name)
                    .filter(\.$ip == storeDatabase.ip)
                    .with(\.$dbAdmin)
                    .with(\.$tables){
                        table in
                        table.with(\.$database)
                    }
                    .with(\.$creatorUser)
                    .first()
                    .unwrap(or: Abort(.notFound))
                
            }.flatMapThrowing{
                return try $0.asPublic()
            }
       
    }
    
    func getAllDatabase(req: Request) throws -> EventLoopFuture<[DatabaseKelpel.Public]> {
        
        let user = try req.auth.require(User.self)
        
        return DatabaseKelpel.query(on: req.db)
            .with(\.$dbAdmin)
            .with(\.$tables)
            .with(\.$creatorUser)
            .all()
            .flatMapThrowing{
                databaseResults in
                let databaseResultsPublic = try databaseResults.map({try $0.asPublic()})
                
                return databaseResultsPublic
            }

    }
    
    func getDatabase(req: Request) throws -> EventLoopFuture<DatabaseKelpel.Public> {
        
        let user = try req.auth.require(User.self)
        
        guard let databaseId = req.parameters.get("databaseid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        return DatabaseKelpel.query(on: req.db)
            .with(\.$dbAdmin)
            .with(\.$tables)
            .with(\.$creatorUser)
            .filter(\.$id == databaseId)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing{
                databaseResult in
                return try databaseResult.asPublic()
            }

    }
    
    
    func getUserDatabase(req:Request) throws -> EventLoopFuture<[DatabaseKelpel.Public]> {
        
        let user = try req.auth.require(User.self)
        
        return DatabaseKelpel.query(on: req.db)
            .with(\.$dbAdmin)
            .with(\.$tables)
            .with(\.$creatorUser)
            .group(.or){
                group in
                group.filter(\.$dbAdmin.$id == user.id).filter(\.$creatorUser.$id == user.id!)
            }
            .all()
            .flatMapThrowing{
                databaseResults in
                let databaseResultsPublic = try databaseResults.map({try $0.asPublic()})
                
                return databaseResultsPublic
            }
    }
    
    func registerDBA(req:Request)throws -> EventLoopFuture<HTTPStatus> {
        let admin = try req.auth.require(User.self)
        let userPermits: [Roles] = [.administrator,.engineerSr, .engineer]
        
        guard let userId = req.parameters.get("userid", as: UUID.self), let databaseId = req.parameters.get("databaseid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
      let userQuery = User.query(on: req.db)
            .filter(\.$id == userId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        let databaseQuery = DatabaseKelpel.query(on: req.db)
            .with(\.$creatorUser)
            .with(\.$dbAdmin)
            .filter(\.$id == databaseId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return userQuery.and(databaseQuery)
            .flatMap{
            user,database in
                guard userPermits.contains(user.role), database.dbAdmin == nil, admin.role == .administrator || admin.id == database.creatorUser.id! else {
                    return req.eventLoop.future(error: DatabaseTableError.cantGrantPermissions)
                }
                
                return DatabaseKelpel.query(on: req.db)
                    .filter(\.$id == databaseId)
                    .set(\.$dbAdmin.$id, to: userId)
                    .update()
                
            }.flatMap{
                return req.eventLoop.makeSucceededFuture(.ok)
            }
        
    }
    
    func registerTable(req: Request) throws -> EventLoopFuture<TableKelpel> {
        let admin = try req.auth.require(User.self)
        let newTable = try req.content.decode(NewTableKelpel.self)
        var storeTable: TableKelpel!
        
        guard let databaseId = req.parameters.get("databaseid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        let databaseQuery = DatabaseKelpel.query(on: req.db)
            .with(\.$creatorUser)
            .filter(\.$id == databaseId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        let tableQuery =  TableKelpel.query(on: req.db)
            .filter(\.$name == newTable.name)
            .filter(\.$database.$id == databaseId)
            .first()
           
  
        return databaseQuery.and(tableQuery).flatMap{
            databaseKelpel,tableKelpel in
            guard tableKelpel == nil, admin.role == .administrator || admin.id == databaseKelpel.dbAdmin?.id || admin.id == databaseKelpel.creatorUser.id else {
                return req.eventLoop.future(error: DatabaseTableError.cantCreateTable )
            }
            
            
            storeTable = TableKelpel(name: newTable.name, description: newTable.description, databaseID:databaseId)
            
            return storeTable.save(on: req.db)
            
        }.flatMapThrowing{
            storeTable
        }
     
    }
    
    
    
    func deleteTable(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        
        let user = try req.auth.require(User.self)
        
        guard let tableId = req.parameters.get("tableid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        return TableKelpel.query(on: req.db)
            .with(\.$database)
            .filter(\.$id == tableId)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap{
                table in
                guard user.role == .administrator || user.id == table.database?.dbAdmin?.id || user.id == table.database?.creatorUser.id else {
                    return req.eventLoop.future(error:DatabaseTableError.cantDropTable)
                }
                
                return TableKelpel.query(on: req.db)
                    .filter(\.$id == tableId).delete()
                    
                    
            }.flatMapThrowing{
                return .ok
            
            }

    }
    
    func removeDBAdmin(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        
        let admin = try req.auth.require(User.self)
        
        guard let userId = req.parameters.get("userid", as: UUID.self), let databaseId = req.parameters.get("databaseid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let userQuery = User.query(on: req.db)
            .filter(\.$id == userId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        let databaseQuery = DatabaseKelpel.query(on: req.db)
            .with(\.$dbAdmin)
            .with(\.$creatorUser)
            .filter(\.$id == databaseId)
            .first()
            .unwrap(or: Abort(.notFound))
        
        return userQuery.and(databaseQuery)
            .flatMap{
                user, database in
                print(user)
                print(database.dbAdmin)
                guard let dbAdmin = database.dbAdmin, dbAdmin.id == user.id, admin.role == .administrator || admin.id == database.creatorUser.id else {
                    return req.eventLoop.future(error: DatabaseTableError.cantGrantPermissions)
                }
                
                return DatabaseKelpel.query(on: req.db)
                    .filter(\.$id == databaseId)
                    .set(\.$dbAdmin.$id, to: nil)
                    .update()
                
            }.flatMapThrowing{
                return .ok
            }
    }
    
    
    func deleteDatabase(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let admin = try req.auth.require(User.self)
        
        guard let databaseId = req.parameters.get("databaseid", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let databaseQuery = DatabaseKelpel.query(on:req.db)
            .with(\.$tables)
            .with(\.$dbAdmin)
            .filter(\.$id == databaseId)
            .first()
            .unwrap(or:Abort(.notFound))
                
        return databaseQuery.flatMap{
            database in
            print(database.dbAdmin)
            print(database.dbAdmin == nil)
            guard database.dbAdmin == nil, admin.role == .administrator || admin.id == database.creatorUser.id else {
                return req.eventLoop.future(error: DatabaseTableError.cantDropDatabase)
            }
                       
            return TableKelpel.query(on: req.db)
                .filter(\.$database.$id == databaseId)
                .delete()
                
        }.flatMap{
            return DatabaseKelpel.query(on: req.db)
                .filter(\.$id == databaseId)
                .delete()
                
        }.flatMapThrowing{
            return .ok
        }
    

        
    }
    
     
    func getModelsFromDatabase(req:Request) throws -> EventLoopFuture<[ModelML.Public]> {
        
        let user = try req.auth.require(User.self)
        
        guard let databaseID = req.parameters.get("databaseid", as: UUID.self) else {
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
                let filteredModels = modelML.filter({$0.databases.map({$0.id}).contains(databaseID)})
                let modelMLPublic = try filteredModels.map({try $0.asPublic()})
                
                return modelMLPublic
            }
    
        
    }
    
    func getDatabaseAssignmentsRequest(req:Request) throws -> EventLoopFuture<[ModelMLDatabasePivot.Public]> {
        
        let user = try req.auth.require(User.self)
        
        return DatabaseKelpel.query(on: req.db)
            .with(\.$creatorUser)
            .with(\.$dbAdmin)
            .with(\.$tables)

            .group(.or) { group in
                group.filter(\.$creatorUser.$id == user.id! ).filter(\.$dbAdmin.$id == user.id! )
            }
            .all()
            .flatMap {
                databases -> EventLoopFuture<[ModelMLDatabasePivot]> in
                let databasesId = databases.map({$0.id!})
                return ModelMLDatabasePivot.query(on: req.db)
                    .with(\.$modelML)
                    .with(\.$database){
                        database in
                        database.with(\.$dbAdmin)
                            .with(\.$creatorUser)
                            .with(\.$tables)
                    }
                    .filter(\.$database.$id ~~ databasesId)
                    .filter(\.$toValidate == 1)
                    .all()
                
                
            }.flatMapThrowing {
                pivots  in
                return try pivots.map({try $0.asPublic()})
            }
    
        
    }

    func getDatabaseAssignmentsRequestAdmin(req:Request) throws -> EventLoopFuture<[ModelMLDatabasePivot.Public]> {
        
        let user = try req.auth.require(User.self)
        guard user.role == .administrator else {
            throw Abort(.badRequest)
        }
        return DatabaseKelpel.query(on: req.db)
            .with(\.$creatorUser)
            .with(\.$dbAdmin)
            .with(\.$tables)
            .all()
            .flatMap {
                databases -> EventLoopFuture<[ModelMLDatabasePivot]> in
                let databasesId = databases.map({$0.id!})
                return ModelMLDatabasePivot.query(on: req.db)
                    .with(\.$modelML)
                    .with(\.$database){
                        database in
                        database.with(\.$dbAdmin)
                            .with(\.$creatorUser)
                            .with(\.$tables)
                    }
                    .filter(\.$database.$id ~~ databasesId)
                    .filter(\.$toValidate == 1)
                    .all()
                
                
            }.flatMapThrowing {
                pivots  in
                return try pivots.map({try $0.asPublic()})
            }
    
        
    }
    
}


enum DatabaseTableError {
    case databaseAlreadyExists
    case cantGrantPermissions
    case cantCreateTable
    case cantDropTable
    case cantDropDatabase
}

extension DatabaseTableError: AbortError {
    var description: String {
        reason
    }
    var status: HTTPResponseStatus{
        switch self{
        case .databaseAlreadyExists:
            return .conflict
        case .cantGrantPermissions:
            return .conflict
        case .cantCreateTable:
            return .conflict
        case .cantDropTable:
            return .conflict
        case .cantDropDatabase:
            return .conflict
        }
        
    }
    var reason: String {
        switch self {
        case .databaseAlreadyExists:
            return "Database already exists"
        case .cantGrantPermissions:
            return "Cannot grant permissions to read-only user"
        case .cantCreateTable:
            return "Cannot create table"
        case .cantDropTable:
            return "Cannot drop table"
        case .cantDropDatabase:
            return "Cannot erase database"
        }
    }
    
}

