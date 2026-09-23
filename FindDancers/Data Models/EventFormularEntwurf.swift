//
//  EventFormularEntwurf.swift
//  FindDancers
//
//  Zwischenstand des Event-Formulars. Wird als JSON persistiert, siehe
//  `EventFormularStore`.
//

import Foundation

nonisolated enum EventTyp: String, Codable, CaseIterable, Identifiable, Sendable {
    case Workshop, Kurs, Veranstaltung

    var id: Self { self }
}

/// Die beiden Seiten der Ortsauswahl. Gewechselt wird durch horizontales
/// Wischen über die Adressfelder.
nonisolated enum OrtModus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case bestehenderOrt
    case neuerOrt

    var id: Self { self }

    var titel: String {
        switch self {
        case .bestehenderOrt: return "Bereits hinzugefügter Ort"
        case .neuerOrt: return "Neuer Ort"
        }
    }
}

/// Eingaben für `POST /Venue`.
///
/// Die Adressfelder bleiben Freitext. Die Koordinaten werden nicht getippt,
/// sondern von `OrtKarteView` aus dem Standort bzw. der Kartenmitte gesetzt –
/// deshalb `Double?` und nicht mehr `String`.
nonisolated struct NeuerOrtEntwurf: Codable, Equatable, Sendable {
    var name = ""
    var streetNr = ""
    var zipcode = ""
    var city = ""
    var latitude: Double?
    var longitude: Double?

    private var textfelder: [(bezeichnung: String, wert: String)] {
        [
            ("Ortsname", name),
            ("Straße & Nr.", streetNr),
            ("PLZ", zipcode),
            ("Stadt", city)
        ]
    }

    var istLeer: Bool {
        textfelder.allSatisfy { $0.wert.trimmed.isEmpty } && koordinate == nil
    }

    /// Gültige Koordinate oder `nil`, solange keine gesetzt wurde.
    var koordinate: (latitude: Double, longitude: Double)? {
        guard let breite = latitude, let laenge = longitude,
              (-90...90).contains(breite), (-180...180).contains(laenge) else {
            return nil
        }
        return (breite, laenge)
    }

    /// Die EV-API verlangt für `POST /Venue` jedes Feld – teilweise gefüllt
    /// wird mit `entity-field-missing-value` abgelehnt.
    var fehlendeFelder: [String] {
        var fehlend = textfelder.filter { $0.wert.trimmed.isEmpty }.map(\.bezeichnung)
        if koordinate == nil { fehlend.append("Position auf der Karte") }
        return fehlend
    }

    var istVollstaendig: Bool { fehlendeFelder.isEmpty }

    /// `nil`, solange noch Felder fehlen.
    var anfrage: EVCreateVenueRequest? {
        guard let koordinate,
              textfelder.allSatisfy({ !$0.wert.trimmed.isEmpty }) else {
            return nil
        }
        return EVCreateVenueRequest(
            name: name.trimmed,
            streetNr: streetNr.trimmed,
            zipcode: zipcode.trimmed,
            city: city.trimmed,
            latitude: koordinate.latitude,
            longitude: koordinate.longitude
        )
    }

    init() {}

    /// Feldweise und fehlertolerant, damit ein bereits gespeicherter Entwurf
    /// nicht verworfen wird. `latitude`/`longitude` waren früher Strings –
    /// solche Werte werden hier noch gelesen (inklusive Komma als
    /// Dezimaltrennzeichen).
    init(from decoder: Decoder) throws {
        let werte = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? werte.decode(String.self, forKey: .name)) ?? ""
        streetNr = (try? werte.decode(String.self, forKey: .streetNr)) ?? ""
        zipcode = (try? werte.decode(String.self, forKey: .zipcode)) ?? ""
        city = (try? werte.decode(String.self, forKey: .city)) ?? ""
        latitude = Self.zahl(werte, .latitude)
        longitude = Self.zahl(werte, .longitude)
    }

    private static func zahl(
        _ werte: KeyedDecodingContainer<CodingKeys>,
        _ schluessel: CodingKeys
    ) -> Double? {
        if let zahl = try? werte.decode(Double.self, forKey: schluessel) {
            return zahl
        }
        guard let text = try? werte.decode(String.self, forKey: schluessel) else { return nil }
        return Double(text.trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private enum CodingKeys: String, CodingKey {
        case name, streetNr, zipcode, city, latitude, longitude
    }
}

nonisolated struct EventFormularEntwurf: Codable, Equatable, Sendable {
    /// Geht als `engagementTyp` an die EV-API, siehe integration-aufgaben.md.
    var typ: EventTyp = .Workshop
    var name = ""
    var beschreibung = ""
    var beginn: Date
    var ende: Date
    /// Nur für `EventTyp.Kurs`: letzter Termin der wöchentlichen Reihe.
    /// `nil` heißt „kein Enddatum gesetzt“ – dann wird ein einzelnes Event
    /// angelegt. Bewusst der Name aus der Anforderung.
    var letztes_datum_von_Kurs: Date?
    var ortModus: OrtModus = .bestehenderOrt
    var bestehenderOrtId: String?
    var neuerOrt = NeuerOrtEntwurf()
    /// Tanzname -> ausgewählt. Geht als `taenze` an die EV-API.
    var taenze: [String: Bool] = TanzKatalog.standard
    /// Dateiname des zwischengespeicherten Bildes im Entwurfsordner.
    var bildDateiname: String?

    /// Nur die aktivierten Tänze, in Katalogreihenfolge.
    var aktiveTaenze: [String] {
        TanzKatalog.aktivierte(in: taenze)
    }

    /// Ein Kurs mit gesetztem Enddatum wird als wöchentliche Reihe angelegt.
    var istKursReihe: Bool {
        typ == .Kurs && letztes_datum_von_Kurs != nil
    }

    /// Die wöchentlichen Termine von `beginn` bis einschließlich
    /// `letztes_datum_von_Kurs`; leer, wenn es keine Reihe ist.
    ///
    /// Verglichen wird auf Tagesebene, die Uhrzeit des Enddatums spielt keine
    /// Rolle. Der letzte Termin ist der letzte, der noch auf oder vor dem
    /// Enddatum liegt.
    var kursTermine: [(beginn: Date, ende: Date)] {
        guard istKursReihe, let bis = letztes_datum_von_Kurs else { return [] }

        let kalender = Calendar.current
        let letzterTag = kalender.startOfDay(for: bis)
        var termine: [(beginn: Date, ende: Date)] = []
        var start = beginn
        var schluss = ende

        // 520 Wochen als Sicherheitsnetz gegen eine Endlosschleife.
        while kalender.startOfDay(for: start) <= letzterTag, termine.count < 520 {
            termine.append((start, schluss))
            // `byAdding: .day` rechnet kalendarisch – die Uhrzeit bleibt
            // deshalb auch über eine Zeitumstellung hinweg gleich.
            guard let naechsterStart = kalender.date(byAdding: .day, value: 7, to: start),
                  let naechsterSchluss = kalender.date(byAdding: .day, value: 7, to: schluss) else {
                break
            }
            start = naechsterStart
            schluss = naechsterSchluss
        }
        return termine
    }

    init() {
        let jetzt = Date()
        beginn = jetzt
        ende = jetzt.addingTimeInterval(2 * 60 * 60)
    }

    /// Jedes Feld wird einzeln und fehlertolerant gelesen: ein Entwurf, der mit
    /// einer älteren Version der App geschrieben wurde, soll nicht komplett
    /// verworfen werden, nur weil ein Feld fehlt oder neu hinzugekommen ist.
    init(from decoder: Decoder) throws {
        self.init()
        let werte = try decoder.container(keyedBy: CodingKeys.self)
        typ = (try? werte.decode(EventTyp.self, forKey: .typ)) ?? typ
        name = (try? werte.decode(String.self, forKey: .name)) ?? name
        beschreibung = (try? werte.decode(String.self, forKey: .beschreibung)) ?? beschreibung
        beginn = (try? werte.decode(Date.self, forKey: .beginn)) ?? beginn
        ende = (try? werte.decode(Date.self, forKey: .ende)) ?? ende
        letztes_datum_von_Kurs = try? werte.decode(Date.self, forKey: .letztes_datum_von_Kurs)
        ortModus = (try? werte.decode(OrtModus.self, forKey: .ortModus)) ?? ortModus
        bestehenderOrtId = try? werte.decode(String.self, forKey: .bestehenderOrtId)
        neuerOrt = (try? werte.decode(NeuerOrtEntwurf.self, forKey: .neuerOrt)) ?? neuerOrt
        // Auf den aktuellen Katalog ziehen: ein Entwurf aus einer Version mit
        // anderer Tanzliste verliert dadurch nichts Gültiges.
        taenze = TanzKatalog.normalisiert(
            (try? werte.decode([String: Bool].self, forKey: .taenze)) ?? [:]
        )
        bildDateiname = try? werte.decode(String.self, forKey: .bildDateiname)
    }

    private enum CodingKeys: String, CodingKey {
        case typ, name, beschreibung, beginn, ende, letztes_datum_von_Kurs
        case ortModus, bestehenderOrtId, neuerOrt, taenze, bildDateiname
    }
}

nonisolated extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
