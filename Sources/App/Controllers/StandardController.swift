//
//  File.swift
//
//
//  Created by Alejandro Cosain on 15/02/24.
//

import Foundation
import Fluent
import Vapor

struct NewStandard: Content {
    
    let name: String
    let type: String
    let description: String
    
}

struct StandardController: RouteCollection {
    
    func boot(routes: Vapor.RoutesBuilder) throws {
        let standardRoute = routes.grouped("standard")
        let tokenProtected = standardRoute.grouped(Token.authenticator())
        
        tokenProtected.post("register", use: registerStandard)
        tokenProtected.delete("delete",":standardid", use: deleteStandard)
        tokenProtected.get("all", use:getAllStandards)
    }
    
    func registerStandard(req: Request) throws -> EventLoopFuture<Standard> {
    
        let user = try req.auth.require(User.self)
    
        let newStandard = try req.content.decode(NewStandard.self)
        
        var storeStandard: Standard!
        
        return CodeLang.query(on: req.db)
            .filter(\.$name == newStandard.name)
            .first()
            .flatMap{
                queryResult in
                guard queryResult == nil, user.role == .administrator || user.role == .scientistSr || user.role == .engineerSr || user.role == .architectSr  else {
                    return req.eventLoop.future(error:StandardError.standardAlreadyExists)
                }
                
                storeStandard = Standard(name: newStandard.name, type: newStandard.type, description: newStandard.description)
        
                
                return storeStandard.save(on: req.db)
            }.flatMapThrowing {
               return storeStandard
            }
    }
    
    func deleteStandard(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let admin = try req.auth.require(User.self)
        
        guard let standardId = req.parameters.get("standardid", as: UUID.self), admin.role == .administrator else {
            throw Abort(.badRequest)
        }
        
        return Standard.query(on: req.db)
            .filter(\.$id == standardId)
            .first()
            .flatMap{
                standard in
                guard standard != nil else {
                    return req.eventLoop.future(error:StandardError.doesNotExist)
                }
                
                return Standard.query(on: req.db)
                    .filter(\.$id == standardId)
                    .delete()
                
            }.flatMapThrowing{
                return .ok
            }
        
    }
    
    func getAllStandards(req:Request) throws -> EventLoopFuture< [Standard]>{
        let user = try req.auth.require(User.self)
        
        return Standard.query(on:req.db)
            .all()

        
    }
        
    
    
    
    
}

enum StandardError {
    case standardAlreadyExists

    case doesNotExist
}

extension StandardError: AbortError {
    var description: String {
        reason
    }
    var status: HTTPResponseStatus{
        switch self{
        case .standardAlreadyExists:
            return .conflict
        case .doesNotExist:
            return .conflict
        }
        
    }
    var reason: String {
        switch self {
        case .standardAlreadyExists:
            return "Standaard already exists"
        case .doesNotExist:
            return "Standard does not exists"
        }
    }
    
}


