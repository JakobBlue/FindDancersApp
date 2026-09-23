//
//  StandortDienst.swift
//  FindDancers
//
//  Ermittelt den aktuellen Standort für die Ortsauswahl.
//

import CoreLocation

nonisolated enum StandortDienst {
    enum Fehler: LocalizedError {
        case verweigert
        case nichtVerfuegbar

        var errorDescription: String? {
            switch self {
            case .verweigert:
                return "Kein Zugriff auf den Standort. In den Einstellungen unter „Ortungsdienste“ freigeben."
            case .nichtVerfuegbar:
                return "Standort konnte nicht ermittelt werden."
            }
        }
    }

    /// Liefert die erste verfügbare Position.
    ///
    /// `CLLocationUpdate.liveUpdates()` fragt die Berechtigung beim ersten
    /// Iterieren selbst ab – ein eigener `CLLocationManager` samt Delegate ist
    /// dafür nicht nötig. Die Schleife wird nach dem ersten Treffer verlassen,
    /// wir brauchen keinen dauerhaften Stream.
    static func aktuellePosition() async throws -> CLLocationCoordinate2D {
        for try await aktualisierung in CLLocationUpdate.liveUpdates() {
            if let ort = aktualisierung.location {
                return ort.coordinate
            }
            if aktualisierung.authorizationDenied {
                throw Fehler.verweigert
            }
        }
        throw Fehler.nichtVerfuegbar
    }
}
