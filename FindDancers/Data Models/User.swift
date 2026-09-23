//
//  User.swift
//  FindDancers
//
//  Created by Jakob Tobias Weitzel on 03.08.26.
//

import Foundation

enum UserType: String, Codable {
    case organisator
    case user
}

struct User: Codable {
    var name: String
    var type: UserType
    /// `UserAccountId` aus der EV-API, wird für die Anmeldung benötigt.
    var userAccountId: String?
    /// `OrganizerId` aus der EV-API, wird beim Erstellen von Engagements benötigt.
    var organizerId: String?
    var email: String?
}
