//
//  ProfilView.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 16.03.25.
//

import SwiftUI

struct ProfilView: View {
    @Binding var sessionData: AppSessionData?
    
    var body: some View {
        VStack(spacing:20) {
            Text("angemeldet mit Namen: \(sessionData?.user?.name ?? "nil")")
            Button("Logout") {
                guard var currentSessionData = sessionData else { return }
                currentSessionData.user = nil
                if SessionDataManager.shared.save(currentSessionData) {
                    sessionData = currentSessionData
                }
                Task { await EVAPIClient.shared.clearCredentials() }
            }
            .padding()
            .buttonStyle(.bordered)
        }
        .onAppear {
            if let savedData = SessionDataManager.shared.load() {
                self.sessionData = savedData
            }
        }
    }
}

#Preview {
    ProfilView(sessionData: .constant(AppSessionData(user: nil)))
}
