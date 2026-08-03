//
//  SessionDataManager.swift
//  FindDancers
//
//  Created by Jakob Tobias Weitzel on 03.08.26.
//

import Foundation

final class SessionDataManager {
    static let shared = SessionDataManager()
    
    private let fileName = "session.json"
    
    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }
    
    private init() {}
    
    // MARK: - Speichern
    
    @discardableResult
    func save(_ data: AppSessionData) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let encodedData = try encoder.encode(data)
            
            try encodedData.write(to: fileURL, options: [.atomic, .completeFileProtection])
            print("Daten erfolgreich gespeichert unter \(fileURL.path)")
            return true
        } catch {
            print("Fehler beim Speichern: \(error.localizedDescription)")
            return false
        }
    }
    
    //MARK: - Laden
    func load() -> AppSessionData? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Noch keine Speicherdatei vorhanden.")
            return nil
        }
        
        do {
            let rawData = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let data = try decoder.decode(AppSessionData.self, from: rawData)
            return data
        } catch {
            print("Fehler beim Laden: \(error.localizedDescription)")
            return nil
        }
    }
    
    func loadOrCreate() -> AppSessionData {
        if let data = load() {
            return data
        }
        
        let data = AppSessionData(user: nil)
        save(data)
        return data
    }
}
