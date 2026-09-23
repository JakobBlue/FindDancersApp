//
//  EVAPIModels.swift
//  FindDancers
//
//  Codable-Typen für die EV-API (siehe api_docs.json).
//
//  Alle Typen sind `nonisolated`, weil das Projekt standardmäßig auf dem
//  MainActor isoliert ist – der `EVAPIClient` ist aber ein eigener Actor.
//

import Foundation

// MARK: - Antwort-Hülle für die paginierten Query-Endpunkte

nonisolated struct EVPage<Item: Decodable & Sendable>: Decodable, Sendable {
    var items: [Item]
    var pageSize: Int?
    var pageNumber: Int?
    var totalPages: Int?
    var totalItems: Int?
}

// MARK: - Entitäten

nonisolated struct EVOrganizer: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String?
}

nonisolated struct EVUserAccount: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String?
    var email: String?
    var organizer: EVOrganizer?
}

nonisolated struct EVVenue: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String?
    var latitude: Double?
    var longitude: Double?
    var streetNr: String?
    var zipcode: String?
    var city: String?
}

nonisolated struct EVEngagement: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String?
    var start: String?
    var end: String?
    var description: String?
    var venueId: String?
    var venue: EVVenue?
}

// MARK: - Request-Bodies

nonisolated struct EVCreateOrganizerRequest: Encodable {
    var name: String
}

nonisolated struct EVCreateUserAccountRequest: Encodable {
    var name: String
    var email: String
    var password: String
}

/// Für `POST /Venue` sind alle Felder Pflicht – der Server lehnt fehlende
/// Werte mit `entity-field-missing-value` ab.
nonisolated struct EVCreateVenueRequest: Encodable {
    var name: String
    var streetNr: String
    var zipcode: String
    var city: String
    var latitude: Double
    var longitude: Double
}

nonisolated struct EVCreateEngagementRequest: Encodable {
    var title: String
    var start: String
    var end: String
    var description: String
    var venueId: String?
}

// MARK: - Fehler-Body

nonisolated struct EVErrorBody: Decodable {
    var message: String?
    var errorType: String?
}

// MARK: - Datumsformat

nonisolated enum EVAPIDateFormat {
    /// Die API überträgt `start`/`end` als String. Das Backend erwartet eine
    /// Java-`LocalDateTime`, also ein ISO-Datum ohne Zeitzonen-Suffix
    /// (z. B. `2026-09-21T16:13:20`).
    static let localDateTime = Date.ISO8601FormatStyle(timeZone: .current)
        .year().month().day()
        .dateSeparator(.dash)
        .dateTimeSeparator(.standard)
        .time(includingFractionalSeconds: false)
        .timeSeparator(.colon)

    static func string(from date: Date) -> String {
        date.formatted(localDateTime)
    }

    static func date(from string: String) -> Date? {
        try? Date(string, strategy: localDateTime)
    }
}
