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

/// Eingaben für `POST /Venue`. Die Koordinaten bleiben Strings, damit auch ein
/// halb eingetippter Wert („49,“) erhalten bleibt und nichts verloren geht.
nonisolated struct NeuerOrtEntwurf: Codable, Equatable, Sendable {
    var name = ""
    var streetNr = ""
    var zipcode = ""
    var city = ""
    var latitude = ""
    var longitude = ""

    private var textfelder: [(bezeichnung: String, wert: String)] {
        [
            ("Ortsname", name),
            ("Straße & Nr.", streetNr),
            ("PLZ", zipcode),
            ("Stadt", city)
        ]
    }

    var istLeer: Bool {
        textfelder.allSatisfy { $0.wert.trimmed.isEmpty }
            && latitude.trimmed.isEmpty
            && longitude.trimmed.isEmpty
    }

    /// Die EV-API verlangt für `POST /Venue` jedes Feld – teilweise gefüllt
    /// wird mit `entity-field-missing-value` abgelehnt.
    var fehlendeFelder: [String] {
        var fehlend = textfelder.filter { $0.wert.trimmed.isEmpty }.map(\.bezeichnung)
        if Self.zahl(latitude) == nil { fehlend.append("Breitengrad") }
        if Self.zahl(longitude) == nil { fehlend.append("Längengrad") }
        return fehlend
    }

    var istVollstaendig: Bool { fehlendeFelder.isEmpty }

    /// `nil`, solange noch Felder fehlen.
    var anfrage: EVCreateVenueRequest? {
        guard let breite = Self.zahl(latitude), let laenge = Self.zahl(longitude),
              (-90...90).contains(breite), (-180...180).contains(laenge),
              textfelder.allSatisfy({ !$0.wert.trimmed.isEmpty }) else {
            return nil
        }
        return EVCreateVenueRequest(
            name: name.trimmed,
            streetNr: streetNr.trimmed,
            zipcode: zipcode.trimmed,
            city: city.trimmed,
            latitude: breite,
            longitude: laenge
        )
    }

    /// Akzeptiert Komma und Punkt als Dezimaltrennzeichen.
    private static func zahl(_ text: String) -> Double? {
        Double(text.trimmed.replacingOccurrences(of: ",", with: "."))
    }
}

nonisolated struct EventFormularEntwurf: Codable, Equatable, Sendable {
    /// Rein lokal – die EV-API kennt für ein Engagement keinen Typ.
    var typ: EventTyp = .Workshop
    var name = ""
    var beschreibung = ""
    var beginn: Date
    var ende: Date
    var ortModus: OrtModus = .bestehenderOrt
    var bestehenderOrtId: String?
    var neuerOrt = NeuerOrtEntwurf()
    /// Dateiname des zwischengespeicherten Bildes im Entwurfsordner.
    var bildDateiname: String?

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
        ortModus = (try? werte.decode(OrtModus.self, forKey: .ortModus)) ?? ortModus
        bestehenderOrtId = try? werte.decode(String.self, forKey: .bestehenderOrtId)
        neuerOrt = (try? werte.decode(NeuerOrtEntwurf.self, forKey: .neuerOrt)) ?? neuerOrt
        bildDateiname = try? werte.decode(String.self, forKey: .bildDateiname)
    }

    private enum CodingKeys: String, CodingKey {
        case typ, name, beschreibung, beginn, ende
        case ortModus, bestehenderOrtId, neuerOrt, bildDateiname
    }
}

nonisolated extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
