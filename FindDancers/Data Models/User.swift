//
//  User.swift
//  FindDancers
//
//  Created by Jakob Tobias Weitzel on 03.08.26.
//

import Foundation

enum UserType: String, Codable {
    case organisator
    case nutzer
}

struct User: Codable {
    var name: String
    var type: UserType
}
