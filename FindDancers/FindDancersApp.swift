//
//  FindDancersApp.swift
//  FindDancers
//
//  Created by Jakob Tobias Weitzel on 03.08.26.
//

import SwiftUI

@main
struct FindDancersApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var sessionData = SessionDataManager.shared.load() ?? AppSessionData(user: nil)
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                SessionDataManager.shared.save(sessionData)
            }
        }
    }
}
