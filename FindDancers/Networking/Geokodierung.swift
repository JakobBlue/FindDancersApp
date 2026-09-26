//
//  Geokodierung.swift
//  FindDancers
//
//  Adresse -> Koordinate über Nominatim (OpenStreetMap).
//

import Foundation

nonisolated struct GeocodeTreffer: Decodable, Sendable, Identifiable, Equatable {
    /// Nominatim liefert lat/lon als Strings, nicht als Zahlen.
    let lat: String
    let lon: String
    let anzeigeName: String
    /// Wie gut der Treffer zur Anfrage passt (0…1).
    let wichtigkeit: Double?
    let osmId: Int?

    var id: String { "\(osmId ?? 0)-\(lat)-\(lon)" }

    var koordinate: (latitude: Double, longitude: Double)? {
        guard let breite = Double(lat), let laenge = Double(lon),
              (-90...90).contains(breite), (-180...180).contains(laenge) else {
            return nil
        }
        return (breite, laenge)
    }

    enum CodingKeys: String, CodingKey {
        case lat
        case lon
        case anzeigeName = "display_name"
        case wichtigkeit = "importance"
        case osmId = "osm_id"
    }
}

nonisolated struct GeocodeAntwort: Sendable {
    var treffer: [GeocodeTreffer]
    /// `true`, wenn erst ohne die PLZ etwas gefunden wurde. Dann passt die
    /// eingegebene PLZ nicht zur Straße – ein Hinweis wert.
    var plzIgnoriert: Bool
}

nonisolated enum GeokodierungFehler: LocalizedError {
    case ungueltigeAnfrage
    case zuVieleAnfragen
    case serverFehler(status: Int)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .ungueltigeAnfrage:
            return "Adresse konnte nicht in eine Suchanfrage übersetzt werden."
        case .zuVieleAnfragen:
            return "Zu viele Adressabfragen in kurzer Zeit. Bitte kurz warten."
        case .serverFehler(let status):
            return "Adresssuche nicht erreichbar (Fehler \(status))."
        case .transport(let fehler):
            return "Adresssuche nicht erreichbar: \(fehler.localizedDescription)"
        }
    }
}

nonisolated enum Geokodierung {
    /// Nominatim verlangt einen eindeutigen User-Agent mit Kontaktmöglichkeit,
    /// sonst werden Anfragen blockiert. Die Repo-URL erfüllt das, ohne eine
    /// persönliche Adresse im Code zu hinterlegen.
    private static let userAgent = "FindDancers/1.0 (+https://github.com/JakobBlue/FindDancersApp)"

    /// Sucht die Adresse strukturiert, also mit getrennten Feldern statt einem
    /// Freitext-Blob. Das liefert verlässlichere Treffer, weil Nominatim weiß,
    /// welcher Teil Straße und welcher Stadt ist.
    ///
    /// Bleibt die Suche mit PLZ ergebnislos, wird einmal ohne PLZ nachgefragt:
    /// eine PLZ, die nicht zur Straße passt, führt sonst zu null Treffern,
    /// obwohl die Straße existiert. `plzIgnoriert` sagt dem Aufrufer, dass er
    /// darauf hinweisen sollte.
    ///
    /// `Accept-Language` nimmt Deutsch und Englisch, damit sowohl „München“ als
    /// auch „Munich“ gefunden werden.
    static func suche(
        strasse: String,
        plz: String,
        stadt: String,
        limit: Int = 1
    ) async throws -> GeocodeAntwort {
        // Ohne Straße oder Stadt ist die Anfrage zu unspezifisch.
        guard !strasse.isEmpty || !stadt.isEmpty else {
            return GeocodeAntwort(treffer: [], plzIgnoriert: false)
        }

        let treffer = try await anfrage(strasse: strasse, plz: plz, stadt: stadt, limit: limit)
        if !treffer.isEmpty || plz.isEmpty {
            return GeocodeAntwort(treffer: treffer, plzIgnoriert: false)
        }

        // Nominatim erlaubt nur eine Anfrage pro Sekunde.
        try? await Task.sleep(for: .milliseconds(1100))
        guard !Task.isCancelled else {
            return GeocodeAntwort(treffer: [], plzIgnoriert: false)
        }

        let ohnePlz = try await anfrage(strasse: strasse, plz: "", stadt: stadt, limit: limit)
        return GeocodeAntwort(treffer: ohnePlz, plzIgnoriert: !ohnePlz.isEmpty)
    }

    private static func anfrage(
        strasse: String,
        plz: String,
        stadt: String,
        limit: Int
    ) async throws -> [GeocodeTreffer] {
        var bestandteile = URLComponents(string: "https://nominatim.openstreetmap.org/search")
        var parameter = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "addressdetails", value: "1")
        ]
        if !strasse.isEmpty { parameter.append(URLQueryItem(name: "street", value: strasse)) }
        if !plz.isEmpty { parameter.append(URLQueryItem(name: "postalcode", value: plz)) }
        if !stadt.isEmpty { parameter.append(URLQueryItem(name: "city", value: stadt)) }
        bestandteile?.queryItems = parameter

        guard let url = bestandteile?.url else { throw GeokodierungFehler.ungueltigeAnfrage }

        var anfrage = URLRequest(url: url)
        anfrage.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        anfrage.setValue("de,en", forHTTPHeaderField: "Accept-Language")
        anfrage.timeoutInterval = 15

        let daten: Data
        let antwort: URLResponse
        do {
            (daten, antwort) = try await URLSession.shared.data(for: anfrage)
        } catch {
            throw GeokodierungFehler.transport(error)
        }

        if let http = antwort as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw http.statusCode == 429
                ? GeokodierungFehler.zuVieleAnfragen
                : GeokodierungFehler.serverFehler(status: http.statusCode)
        }

        return (try? JSONDecoder().decode([GeocodeTreffer].self, from: daten)) ?? []
    }
}
