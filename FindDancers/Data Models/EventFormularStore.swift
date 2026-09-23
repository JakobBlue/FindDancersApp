//
//  EventFormularStore.swift
//  FindDancers
//
//  Persistiert den Event-Entwurf und das ausgewählte Bild.
//

import Foundation
import UniformTypeIdentifiers

/// Speichert den Zwischenstand des Event-Formulars.
///
/// Geschrieben wird sofort bei jeder Änderung und atomar – nicht erst beim
/// Wechsel in den Hintergrund. Nur so übersteht der Entwurf auch ein
/// plötzliches Ausschalten (Akku von 1 % auf 0 %), bei dem die App keinen
/// Lifecycle-Callback mehr bekommt. Ein atomarer Write kann außerdem keine
/// halb geschriebene Datei hinterlassen.
nonisolated final class EventFormularStore: Sendable {
    static let shared = EventFormularStore()

    private let entwurfDateiName = "event-formular-entwurf.json"
    private let bildOrdnerName = "event-formular-bilder"

    private init() {}

    private var dokumente: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var entwurfURL: URL {
        dokumente.appendingPathComponent(entwurfDateiName)
    }

    private var bildOrdner: URL {
        dokumente.appendingPathComponent(bildOrdnerName, isDirectory: true)
    }

    // MARK: - Entwurf

    func laden() -> EventFormularEntwurf {
        guard let rohdaten = try? Data(contentsOf: entwurfURL),
              let entwurf = try? JSONDecoder().decode(EventFormularEntwurf.self, from: rohdaten) else {
            return EventFormularEntwurf()
        }
        return entwurf
    }

    func speichern(_ entwurf: EventFormularEntwurf) {
        do {
            let daten = try JSONEncoder().encode(entwurf)
            try daten.write(to: entwurfURL, options: .atomic)
        } catch {
            print("Entwurf konnte nicht gespeichert werden: \(error.localizedDescription)")
        }
    }

    // MARK: - Bild

    /// Legt die Bilddaten im Entwurfsordner ab und liefert den Dateinamen,
    /// der im Entwurf mitgespeichert wird.
    func bildSpeichern(_ daten: Data, endung: String) -> String? {
        do {
            try FileManager.default.createDirectory(at: bildOrdner, withIntermediateDirectories: true)
            let dateiName = "bild-\(UUID().uuidString).\(endung)"
            try daten.write(to: bildOrdner.appendingPathComponent(dateiName), options: .atomic)
            return dateiName
        } catch {
            print("Bild konnte nicht gespeichert werden: \(error.localizedDescription)")
            return nil
        }
    }

    func bildDaten(_ dateiName: String) -> Data? {
        try? Data(contentsOf: bildOrdner.appendingPathComponent(dateiName))
    }

    func bildLoeschen(_ dateiName: String) {
        try? FileManager.default.removeItem(at: bildOrdner.appendingPathComponent(dateiName))
    }

    func mimeTyp(fuer dateiName: String) -> String {
        let endung = (dateiName as NSString).pathExtension
        return UTType(filenameExtension: endung)?.preferredMIMEType ?? "application/octet-stream"
    }
}
