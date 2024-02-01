//
//  File.swift
//  
//
//  Created by Alejandro Cosain on 01/02/24.
//

import Vapor
import Fluent

enum Roles: String, Codable, CaseIterable {
    
    case user, administrator, scientist,scientistSr, engineer, engineerSr, architect, architectSr
    
    static func withLabel(_ label: String) -> Roles? {
            return self.allCases.first{ "\($0)" == label }
        }
    
}

