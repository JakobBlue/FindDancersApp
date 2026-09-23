//
//  TanzKatalog.swift
//  FindDancers
//
//  Einzige Quelle für die Tanzliste, die als `Engagement.taenze` an die
//  EV-API geschickt wird.
//

import Foundation

nonisolated enum TanzKatalog {
    /// Reihenfolge und Schreibweise wie in `danceFilterView` (NurEventsAnzeige).
    /// Die Namen sind gleichzeitig die Schlüssel der `taenze`-Column und dürfen
    /// deshalb nicht umbenannt werden, ohne die Daten zu migrieren.
    static let namen: [String] = [
        "Wiener Walzer",
        "Langsamer Walzer",
        "Foxtrott",
        "Diskofox",
        "Slowfox",
        "Quickstepp",
        "Jive",
        "Rumba",
        "Cha Cha Cha",
        "Samba",
        "Europäischer Tango",
        "Argentinescher Tango",
        "Salsa",
        "Kizomba",
        "Bachata",
        "Zouk",
        "Salsa Mexicana",
        "Pachanga",
        "West Coast Swing"
    ]

    /// Ausgangszustand: alle Tänze aus.
    static var standard: [String: Bool] {
        Dictionary(uniqueKeysWithValues: namen.map { ($0, false) })
    }

    /// Ergänzt fehlende und entfernt unbekannte Tänze. Nötig, wenn ein
    /// gespeicherter Entwurf oder eine Server-Antwort aus einer Version mit
    /// anderer Tanzliste stammt.
    static func normalisiert(_ auswahl: [String: Bool]) -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: namen.map { ($0, auswahl[$0] ?? false) })
    }

    /// Die aktivierten Tänze in der Reihenfolge des Katalogs.
    static func aktivierte(in auswahl: [String: Bool]) -> [String] {
        namen.filter { auswahl[$0] == true }
    }
}
