//
//  EVAPIClient.swift
//  FindDancers
//
//  REST-Anbindung an die EV-API (Event Management API, siehe api_docs.json).
//

import Foundation

nonisolated enum EVAPIConfiguration {
    /// `servers[0].url` aus api_docs.json.
    static let baseURL = URL(string: "http://localhost:8080")!
}

nonisolated enum EVAPIError: LocalizedError {
    case invalidURL
    case unauthorized
    case server(status: Int, message: String?)
    case invalidResponse
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Die Server-Adresse ist ungültig."
        case .unauthorized:
            return "Name oder Passwort ist falsch."
        case .server(let status, let message):
            if let message, !message.isEmpty {
                return "Server-Fehler \(status): \(message)"
            }
            return "Server-Fehler \(status)."
        case .invalidResponse:
            return "Unerwartete Antwort vom Server."
        case .decoding(let error):
            return "Antwort konnte nicht gelesen werden: \(error.localizedDescription)"
        case .transport(let error):
            return "Keine Verbindung zum Server: \(error.localizedDescription)"
        }
    }
}

actor EVAPIClient {
    static let shared = EVAPIClient()

    private let baseURL: URL
    private let urlSession: URLSession
    private var credentials: EVAPICredentials?

    init(baseURL: URL = EVAPIConfiguration.baseURL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.credentials = EVCredentialStore.load()
    }

    // MARK: - Zugangsdaten

    func setCredentials(_ credentials: EVAPICredentials) {
        self.credentials = credentials
        EVCredentialStore.save(credentials)
    }

    func clearCredentials() {
        credentials = nil
        EVCredentialStore.clear()
    }

    func hasCredentials() -> Bool {
        credentials != nil
    }

    // MARK: - Anmeldung

    /// Prüft die Zugangsdaten gegen die HTTP-Basic-Authentifizierung der EV-API.
    ///
    /// Die API hat keinen eigenen Login-Endpunkt: `security` gilt global für alle
    /// Operationen, und `GET /UserAccount` ist eine der geschützten. Der Aufruf ist
    /// deshalb gleichzeitig Passwortprüfung und Möglichkeit, den zugehörigen
    /// Organizer zu finden. Bei Erfolg werden die Zugangsdaten übernommen.
    ///
    /// `email` ist der Basic-Auth-Benutzername; der `name` funktioniert nicht.
    /// Die `organizer`-Relation liefert der Server nur, wenn sie über `_fields`
    /// explizit angefordert wird.
    func signIn(email: String, password: String) async throws -> EVUserAccount? {
        let candidate = EVAPICredentials(username: email, password: password)
        let page: EVPage<EVUserAccount> = try await send(
            method: "GET",
            path: "/UserAccount",
            query: [
                URLQueryItem(name: "_size", value: "1000"),
                URLQueryItem(name: "_fields", value: "id,name,email,organizer")
            ],
            credentials: candidate,
            as: EVPage<EVUserAccount>.self
        )

        setCredentials(candidate)

        let needle = email.lowercased()
        return page.items.first { $0.email?.lowercased() == needle }
    }

    // MARK: - Organizer

    /// Registrierung eines Organisators.
    ///
    /// Die EV-API hat keinen kombinierten Registrierungs-Endpunkt: `Organizer`
    /// besteht nur aus einem Namen, die Zugangsdaten hängen am `UserAccount`.
    /// Deshalb werden beide Entitäten angelegt und über
    /// `PUT /Organizer/{organizerId}/Staff/{userAccountId}` verknüpft.
    ///
    /// Der `UserAccount` wird ohne `Authorization`-Header erzeugt, damit die
    /// Basic-Auth-Prüfung die noch nicht existierenden Zugangsdaten nicht
    /// ablehnt. Erst danach werden sie für die Folgeaufrufe übernommen.
    func registerOrganizer(
        name: String,
        email: String,
        password: String
    ) async throws -> (organizer: EVOrganizer, account: EVUserAccount) {
        let account = try await createUserAccount(name: name, email: email, password: password)
        setCredentials(EVAPICredentials(username: email, password: password))

        do {
            let organizer = try await createOrganizer(name: name)
            try await addStaff(organizerId: organizer.id, userAccountId: account.id)
            return (organizer, account)
        } catch {
            clearCredentials()
            throw error
        }
    }

    /// `POST /Organizer`
    func createOrganizer(name: String) async throws -> EVOrganizer {
        try await send(
            method: "POST",
            path: "/Organizer",
            body: encode(EVCreateOrganizerRequest(name: name)),
            as: EVOrganizer.self
        )
    }

    /// `POST /UserAccount`
    func createUserAccount(name: String, email: String, password: String) async throws -> EVUserAccount {
        try await send(
            method: "POST",
            path: "/UserAccount",
            body: encode(EVCreateUserAccountRequest(name: name, email: email, password: password)),
            as: EVUserAccount.self
        )
    }

    /// `PUT /Organizer/{organizerId}/Staff/{userAccountId}`
    func addStaff(organizerId: String, userAccountId: String) async throws {
        try await sendIgnoringResponse(
            method: "PUT",
            path: "/Organizer/\(organizerId)/Staff/\(userAccountId)"
        )
    }

    // MARK: - Engagement

    /// `POST /Engagement`
    func createEngagement(
        title: String,
        start: Date,
        end: Date,
        description: String,
        venueId: String?
    ) async throws -> EVEngagement {
        let request = EVCreateEngagementRequest(
            title: title,
            start: EVAPIDateFormat.string(from: start),
            end: EVAPIDateFormat.string(from: end),
            description: description,
            venueId: venueId
        )
        return try await send(
            method: "POST",
            path: "/Engagement",
            body: encode(request),
            as: EVEngagement.self
        )
    }

    /// `PUT /Engagement/{id}/Organizers`
    func assignOrganizers(engagementId: String, organizerIds: [String]) async throws {
        try await sendIgnoringResponse(
            method: "PUT",
            path: "/Engagement/\(engagementId)/Organizers",
            body: encode(organizerIds)
        )
    }

    // MARK: - Venue

    /// `GET /Venue` – ein Engagement verweist über `venueId` auf eine bestehende
    /// Venue. Neue Orte lassen sich nicht aus einem einzelnen Ortsnamen anlegen:
    /// `POST /Venue` verlangt zusätzlich streetNr, zipcode, city, latitude und
    /// longitude.
    func venues() async throws -> [EVVenue] {
        let page: EVPage<EVVenue> = try await send(
            method: "GET",
            path: "/Venue",
            query: [URLQueryItem(name: "_size", value: "1000")],
            as: EVPage<EVVenue>.self
        )
        return page.items
    }

    /// `POST /Venue` – alle Felder sind Pflicht.
    func createVenue(_ venue: EVCreateVenueRequest) async throws -> EVVenue {
        try await send(
            method: "POST",
            path: "/Venue",
            body: encode(venue),
            as: EVVenue.self
        )
    }

    // MARK: - Transport

    private func encode(_ value: some Encodable) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private func send<Response: Decodable>(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        credentials: EVAPICredentials? = nil,
        as responseType: Response.Type
    ) async throws -> Response {
        let data = try await perform(
            makeRequest(method: method, path: path, query: query, body: body, credentials: credentials)
        )
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw EVAPIError.decoding(error)
        }
    }

    private func sendIgnoringResponse(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        credentials: EVAPICredentials? = nil
    ) async throws {
        _ = try await perform(
            makeRequest(method: method, path: path, query: query, body: body, credentials: credentials)
        )
    }

    private func makeRequest(
        method: String,
        path: String,
        query: [URLQueryItem],
        body: Data?,
        credentials overrideCredentials: EVAPICredentials?
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw EVAPIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else { throw EVAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let credentials = overrideCredentials ?? credentials {
            request.setValue(credentials.basicAuthHeaderValue, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw EVAPIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw EVAPIError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401, 403:
            throw EVAPIError.unauthorized
        default:
            let message = try? JSONDecoder().decode(EVErrorBody.self, from: data).message
            throw EVAPIError.server(status: http.statusCode, message: message)
        }
    }
}
