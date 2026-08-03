//
//  ContentView.swift
//  FindDancers
//
//  Created by Jakob Tobias Weitzel on 03.08.26.
//

import SwiftUI

struct ContentView: View {
    @State private var sessionData: AppSessionData?
    @State private var showOrganisatorAnmeOderRegis = false
    @State private var showRegistrierungOrganisator = false
    @State private var showLoginOrganisator = false
    @State private var showLoginUser = false
    @State private var showRegistrierungUser = false
    @State private var showUserAnmeOderRegis = false
    @State private var showCreateEvents = false
    @State private var jumpToContentView = false
    @State private var registrierungOrganisatorDaten = RegistrierungOrganisatorDaten(name: "", password: "")
    @State private var nameOrganisator: String = ""
    @State private var passwortOrganisator = ""
    @State private var nameUser: String = ""
    @State private var passwortUser: String = ""
    @State private var responseText = ""
    @State private var typingTimer: Timer? = nil
    
    func startTypingTimer(inputString: String, valueString: String) {
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            //             DatabaseManager().updateFirstEntry(inputString: inputString, valueString: valueString)
            //             DatabaseManager().printRegistrierungOrganisatorDaten()
        }
    }
    
    var body: some View {
        VStack{
            if sessionData?.user != nil {
                ProfilView(sessionData: $sessionData)
            } else {
                VStack (spacing: 40){
                    Text("Was trifft auf dich am besten zu?")
                    Button("Ich möchte tanzen gehen"){
                        showUserAnmeOderRegis = true
                    }.buttonStyle(.bordered)
                    Button("Wir möchten Tanzgelegenheiten anbieten"){
                        showOrganisatorAnmeOderRegis = true
                    }.buttonStyle(.bordered)
                }.sheet(isPresented: $showOrganisatorAnmeOderRegis) {
                    VStack(spacing: 40){
                        Text("Als Organisator")
                        Button("Anmelden"){
                            showLoginOrganisator = true
                        }.buttonStyle(.bordered)
                        Button("Registrieren"){
                            showRegistrierungOrganisator = true
                        }.buttonStyle(.bordered)
                    }.sheet(isPresented: $showRegistrierungOrganisator, content: {
                        RegistrierungOrganisator
                    })
                    .sheet(isPresented: $showLoginOrganisator, content: {
                        AnmeldungOrganisator
                    })
                }
                .sheet(isPresented: $showUserAnmeOderRegis, content: {
                    VStack(spacing: 40) {
                        Text("Als Benutzer")
                        Button("Anmelden"){
                            showLoginUser = true
                        }.buttonStyle(.bordered)
                        Button("Registrieren"){
                            showRegistrierungUser = true
                        }.buttonStyle(.bordered)
                    }.sheet(isPresented: $showRegistrierungUser, content: {
                        RegistrierungNutzerView()
                    })
                    .sheet(isPresented: $showLoginUser, content: {
                        AnmeldungUser
                    })
                })
            }
        }
        .padding()
        .onAppear {
            sessionData = SessionDataManager.shared.loadOrCreate()
        }
    }
    
    
    var RegistrierungOrganisator: some View {
        let isFormValid = !registrierungOrganisatorDaten.name.isEmpty && !registrierungOrganisatorDaten.password.isEmpty
        
        return NavigationStack {
            VStack(spacing: 20) {
                Text("Bitte geben Sie Ihre Daten ein:")
                TextField("Name", text: $registrierungOrganisatorDaten.name, onEditingChanged: { _ in startTypingTimer(inputString: "name", valueString: registrierungOrganisatorDaten.name) }).multilineTextAlignment(.center)
                SecureField("Passwort", text: $passwortOrganisator).textFieldStyle(.roundedBorder).frame(width: 300, height: 40).multilineTextAlignment(.center)
                TextField("Adresse", text: Binding(
                    get: { registrierungOrganisatorDaten.adresse ?? "" },
                    set: { registrierungOrganisatorDaten.adresse = $0.isEmpty ? nil : $0; startTypingTimer(inputString: "adresse", valueString: registrierungOrganisatorDaten.adresse ?? "")  }
                ))
                .multilineTextAlignment(.center)
                TextField("E-Mail", text: Binding(
                    get: { registrierungOrganisatorDaten.email ?? "" },
                    set: { registrierungOrganisatorDaten.email = $0.isEmpty ? nil : $0; startTypingTimer(inputString: "email", valueString: registrierungOrganisatorDaten.email ?? "")  }
                ))
                .multilineTextAlignment(.center)
                Button("Abschicken") {
                   
                }.buttonStyle(.bordered)
                    .disabled(!isFormValid)
                Spacer()
                Button("Direkt zu Create Events"){
                
                }.buttonStyle(.bordered)
                    .background(Color.blue.opacity(0.1))
            }
            .padding()
            .navigationDestination(isPresented: $showCreateEvents) {
                // CreateEvents(loggedInUser: UserSession.shared.loggedInUser)
            }
        }
    }
    
    var AnmeldungOrganisator: some View {
        VStack {
            VStack (spacing: 40){
                Text("Anmelden als Organisator").font(.headline).fontWeight(.bold)
                TextField("Name", text: $nameOrganisator).textFieldStyle(.roundedBorder).frame(width: 300, height: 40).multilineTextAlignment(.center)
                SecureField("Passwort", text: $passwortOrganisator).textFieldStyle(.roundedBorder).frame(width: 300, height: 40).multilineTextAlignment(.center)
                Button("Anmelden"){
                    guard var currentSessionData = sessionData else { return }
                    currentSessionData.user = .init(name: nameOrganisator, type: .organisator)
                    sessionData = currentSessionData
                    SessionDataManager.shared.save(currentSessionData)
                }.buttonStyle(.bordered)
            }.background(Color.gray.opacity(0.1))
                .padding(.horizontal, 30)
        }
    }
    
    var AnmeldungUser: some View {
        VStack (spacing: 40){
            Text("Anmelden als Benutzer").font(.headline).fontWeight(.bold)
            TextField("Name", text: $nameUser).textFieldStyle(.roundedBorder).frame(width: 300, height: 40).multilineTextAlignment(.center)
            SecureField("Passwort", text: $passwortUser).textFieldStyle(.roundedBorder).frame(width: 300, height: 40).multilineTextAlignment(.center)
            Button("Anmelden"){
                guard var currentSessionData = sessionData else { return }
                currentSessionData.user = .init(name: nameUser, type: .user)
                sessionData = currentSessionData
                SessionDataManager.shared.save(currentSessionData)
            }.buttonStyle(.bordered)
        }
        .background(Color.gray.opacity(0.1))
    }
}

#Preview {
    ContentView()
}
