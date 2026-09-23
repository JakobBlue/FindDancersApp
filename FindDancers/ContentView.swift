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
    @State private var isBusy = false
    @State private var fehlermeldung: String?

    func startTypingTimer(inputString: String, valueString: String) {
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            //             DatabaseManager().updateFirstEntry(inputString: inputString, valueString: valueString)
            //             DatabaseManager().printRegistrierungOrganisatorDaten()
        }
    }

    var body: some View {
        VStack{
            if let user = sessionData?.user {
                authenticatedTabView(for: user)
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

    @ViewBuilder
    func authenticatedTabView(for user: User) -> some View {
        TabView {
            ProfilView(sessionData: $sessionData)
                .tabItem {
                    Label("Profil", systemImage: "person")
                }
            NurCreateEvents(organizerId: user.organizerId)
                .tabItem {
                    Label("Events", systemImage: "calendar")
                }
            if user.type == .user {
                Text("Anfragen")
                    .tabItem {
                        Label("Anfragen", systemImage: "envelope")
                    }
                Text("Chats")
                    .tabItem {
                        Label("Chats", systemImage: "message")
                    }
            }
        }
    }

    var RegistrierungOrganisator: some View {
        let isFormValid = !registrierungOrganisatorDaten.name.isEmpty
            && !passwortOrganisator.isEmpty
            && !(registrierungOrganisatorDaten.email ?? "").isEmpty

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
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                Button("Abschicken") {
                    Task { await registriereOrganisator() }
                }.buttonStyle(.bordered)
                    .disabled(!isFormValid || isBusy)
                if isBusy {
                    ProgressView()
                }
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
        .alert("Registrierung fehlgeschlagen", isPresented: zeigtFehler) {
            Button("OK", role: .cancel) { fehlermeldung = nil }
        } message: {
            Text(fehlermeldung ?? "")
        }
    }

    var AnmeldungOrganisator: some View {
        VStack {
            VStack (spacing: 40){
                Text("Anmelden als Organisator").font(.headline).fontWeight(.bold)
                // Die EV-API erwartet die E-Mail als Basic-Auth-Benutzernamen.
                TextField("E-Mail", text: $nameOrganisator)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300, height: 40)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                SecureField("Passwort", text: $passwortOrganisator).textFieldStyle(.roundedBorder).frame(width: 300, height: 40).multilineTextAlignment(.center)
                Button("Anmelden"){
                    Task { await meldeOrganisatorAn() }
                }.buttonStyle(.bordered)
                    .disabled(nameOrganisator.isEmpty || passwortOrganisator.isEmpty || isBusy)
                if isBusy {
                    ProgressView()
                }
            }.background(Color.gray.opacity(0.1))
                .padding(.horizontal, 30)
        }
        .alert("Anmeldung fehlgeschlagen", isPresented: zeigtFehler) {
            Button("OK", role: .cancel) { fehlermeldung = nil }
        } message: {
            Text(fehlermeldung ?? "")
        }
    }

    var AnmeldungUser: some View {
        VStack (spacing: 40){
            Text("Anmelden als Benutzer").font(.headline).fontWeight(.bold)
            TextField("Name", text: $nameUser).textFieldStyle(.roundedBorder).frame(width: 300, height: 40).multilineTextAlignment(.center)
            SecureField("Passwort", text: $passwortUser).textFieldStyle(.roundedBorder).frame(width: 300, height: 40).multilineTextAlignment(.center)
            Button("Anmelden"){
                guard var currentSessionData = sessionData else { return }
                currentSessionData.user = User(name: nameUser, type: .user)
                sessionData = currentSessionData
                SessionDataManager.shared.save(currentSessionData)
            }.buttonStyle(.bordered)
        }
        .background(Color.gray.opacity(0.1))
    }

    // MARK: - EV-API

    private var zeigtFehler: Binding<Bool> {
        Binding(
            get: { fehlermeldung != nil },
            set: { if !$0 { fehlermeldung = nil } }
        )
    }

    /// Registriert einen Organisator über `POST /Organizer` (plus `UserAccount`
    /// für die Zugangsdaten, siehe `EVAPIClient.registerOrganizer`).
    private func registriereOrganisator() async {
        let name = registrierungOrganisatorDaten.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (registrierungOrganisatorDaten.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let passwort = passwortOrganisator

        isBusy = true
        defer { isBusy = false }

        do {
            let (organizer, account) = try await EVAPIClient.shared.registerOrganizer(
                name: name,
                email: email,
                password: passwort
            )

            uebernehmeAnmeldung(
                User(
                    name: account.name ?? name,
                    type: .organisator,
                    userAccountId: account.id,
                    organizerId: organizer.id,
                    email: account.email ?? email
                )
            )
        } catch {
            fehlermeldung = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Meldet den Organisator über die HTTP-Basic-Authentifizierung der EV-API an.
    private func meldeOrganisatorAn() async {
        let email = nameOrganisator.trimmingCharacters(in: .whitespacesAndNewlines)

        isBusy = true
        defer { isBusy = false }

        do {
            let account = try await EVAPIClient.shared.signIn(
                email: email,
                password: passwortOrganisator
            )

            uebernehmeAnmeldung(
                User(
                    name: account?.name ?? email,
                    type: .organisator,
                    userAccountId: account?.id,
                    organizerId: account?.organizer?.id,
                    email: account?.email ?? email
                )
            )
        } catch {
            fehlermeldung = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func uebernehmeAnmeldung(_ user: User) {
        var currentSessionData = sessionData ?? AppSessionData(user: nil)
        currentSessionData.user = user
        SessionDataManager.shared.save(currentSessionData)
        sessionData = currentSessionData

        passwortOrganisator = ""
        showRegistrierungOrganisator = false
        showLoginOrganisator = false
        showOrganisatorAnmeOderRegis = false
    }
}

#Preview {
    ContentView()
}
