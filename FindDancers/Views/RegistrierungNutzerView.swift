//
//  RegistrierungNutzerView.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 25.03.25.
//

import SwiftUI
import CryptoKit

struct RegistrierungNutzerView: View {
    @State private var registrierungNutzerDaten = RegistrierungNutzerDaten(name: "", passwort: "")
    @State private var responseMessage: String = ""
    
    var body: some View {
        let isFormValid = !registrierungNutzerDaten.name.isEmpty && !registrierungNutzerDaten.passwort.isEmpty
            return NavigationStack {
                Form {
                    VStack(spacing: 20) {
                        Text("Bitte gebe deine Daten ein:")
                        TextField("Name", text: $registrierungNutzerDaten.name).multilineTextAlignment(.center)
                        //                    TextField("Nachname", text: Binding(
                        //                        get: { registrierungNutzerDaten.nachname ?? "" },
                        //                        set: { registrierungNutzerDaten.nachname = $0.isEmpty ? nil : $0;}
                        //                     )).multilineTextAlignment(.center)
                        SecureField("Passwort", text: $registrierungNutzerDaten.passwort).frame(width: 300, height: 40).multilineTextAlignment(.center)
                        TextField("Deine Gegend", text: Binding(
                            get: { registrierungNutzerDaten.gegend ?? "" },
                            set: { registrierungNutzerDaten.gegend = $0.isEmpty ? nil : $0;}
                        ))
                        .multilineTextAlignment(.center)
                        TextField("E-Mail", text: Binding(
                            get: { registrierungNutzerDaten.email ?? "" },
                            set: { registrierungNutzerDaten.email = $0.isEmpty ? nil : $0; }
                        ))
                        .multilineTextAlignment(.center)
                        Button("Abschicken") {
                        
                        }.buttonStyle(.bordered)
                            .disabled(!isFormValid)
                        Spacer()
                        Text(responseMessage)
                    }
                    .padding()
                }
             }
        }
}

struct RegistrierungNutzerDaten: Codable {
    var name: String
//    var nachname: String?
    var email: String?
    var passwort: String
    var age : Int?
    var gegend: String?
}

#Preview {
    RegistrierungNutzerView()
}
