//
//  File.swift
//
//
//  Created by Alejandro Cosain on 15/02/24.
//

import Foundation
import Fluent
import Vapor

struct NewCodeLang: Content {
    
    let name: String
    let type: String
    
}

struct CodeLangController: RouteCollection {
    
    func boot(routes: Vapor.RoutesBuilder) throws {
        let codeLangRoute = routes.grouped("codelang")
        let tokenProtected = codeLangRoute.grouped(Token.authenticator())
        
        tokenProtected.post("register", use: registerCodeLang)
        tokenProtected.delete("delete",":codelangid", use: deleteCodeLang)
        tokenProtected.get("getall", use:getAllCodeLang)
    }
    
    func registerCodeLang(req: Request) throws -> EventLoopFuture<CodeLang> {
    
        let user = try req.auth.require(User.self)
    
        let newCodeLang = try req.content.decode(NewCodeLang.self)
        
        var storeCodeLang: CodeLang!
        
        return CodeLang.query(on: req.db)
            .filter(\.$name == newCodeLang.name)
            .first()
            .flatMap{
                queryResult in
                guard queryResult == nil, user.role == .administrator else {
                    return req.eventLoop.future(error:CodeLangError.codeLangAlreadyExists)
                }
                
                storeCodeLang = CodeLang(name: newCodeLang.name,  type: newCodeLang.type)
                
                return storeCodeLang.save(on: req.db)
            }.flatMapThrowing {
               return storeCodeLang
            }
    }
    
    func deleteCodeLang(req:Request) throws -> EventLoopFuture<HTTPStatus> {
        let admin = try req.auth.require(User.self)
        
        guard let codeLangId = req.parameters.get("codelangid", as: UUID.self), admin.role == .administrator else {
            throw Abort(.badRequest)
        }
        
        return CodeLang.query(on: req.db)
            .filter(\.$id == codeLangId)
            .first()
            .flatMap{
                codelang in
                guard codelang != nil else {
                    return req.eventLoop.future(error:CodeLangError.doesNotExist)
                }
                
                return CodeLang.query(on: req.db)
                    .filter(\.$id == codeLangId)
                    .delete()
                
            }.flatMapThrowing{
                return .ok
            }
        
    }
    
    func getAllCodeLang(req: Request) throws -> EventLoopFuture<[CodeLang]> {
        
        let user = try req.auth.require(User.self)
        
        return CodeLang.query(on: req.db)
            .all()

    }
    
    
}

enum CodeLangError {
    case codeLangAlreadyExists
    case cantGrantPermissions
    case cantCreateCodeLang
    case cantEraseCodeLang
    case doesNotExist
}

extension CodeLangError: AbortError {
    var description: String {
        reason
    }
    var status: HTTPResponseStatus{
        switch self{
        case .codeLangAlreadyExists:
            return .conflict
        case .cantGrantPermissions:
            return .conflict
        case .cantCreateCodeLang:
            return .conflict
        case .cantEraseCodeLang:
            return .conflict
        case .doesNotExist:
            return .conflict
        }
        
    }
    var reason: String {
        switch self {
        case .codeLangAlreadyExists:
            return "Platform already exists"
        case .cantGrantPermissions:
            return "Cannot grant permissions to read-only user"
        case .cantCreateCodeLang:
            return "Cannot create code language"
        case .cantEraseCodeLang:
            return "Cannot erase code language"
        case .doesNotExist:
            return "Code language does not exists"
        }
    }
    
}


