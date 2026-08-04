//
//  AddTanzView.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 18.03.25.
//

import SwiftUI
import Foundation

struct AddTanzView: View {
    @Binding var possibleTänze: [String: Bool]
    @Binding var tänze: [String]
    @State private var newTanz: String = ""
    @State private var newTanz_message: String = ""
    @State private var vorherigeTanzSets: [String: [String: Bool]]? = nil
    @State private var neuerTanzSetName: String = ""
    @State private var neuesTanzSet_gesichert: String? = nil
    
    var body: some View {
        VStack {
            NavigationStack {
                Form {
                    vorherigeTänzeSetsView
                    
                    listOfTogglesView
                    
                    neuerTanzVorschlagView
                }
            }
        }
    }
    
    var textfieldNeuerTanzSetNameView: some View {
        return TextField("Name", text: Binding(
            get: { neuerTanzSetName },
            set: { neuerTanzSetName = $0.isEmpty ? "" : $0 }
        ))
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .multilineTextAlignment(.center)
        .padding()
        .frame(width: 200)
    }
    
    var buttonNeuerTanzSetNameView: some View {
        return  HStack(spacing: 10) {
            textfieldNeuerTanzSetNameView
            Button("Sichern"){
              print("jetzt wäre rest api call, post mit \(neuerTanzSetName) und \(neuesTanzSet_gesichert ?? "nil")")
            }.buttonStyle(.bordered)
                .frame(width: 100, height: 30)
        }
    }
    
    var listVorherigeTanzSetsView: some View {
        let sortedKeys: [String] = (vorherigeTanzSets ?? [:]).keys.sorted(by: >)

        return List {
            ForEach(sortedKeys, id: \.self) { key in
                if let _ = vorherigeTanzSets?[key] {
                    NavigationLink(destination: TanzSetView(
                        tanzSetName: Binding(
                            get: { key },
                            set: { _ in }
                        ),
                        tanzset: Binding(
                            get: { vorherigeTanzSets?[key] ?? [:] },
                            set: { vorherigeTanzSets?[key] = $0 }
                        )
                    )) {
                        Text(key)
                    }
                    .padding(15)
                }
            }
        }
    }
    
    var vorherigeTänzeSetsView: some View {
        return Section(header: Text("Vorherige Tänze Sets")) {
            VStack(spacing: 15) {
                VStack(spacing: 10) {
                    Text("Sicher die aktuelle Auswahl an Tänzen unter den Namen")
                    buttonNeuerTanzSetNameView
                    if neuesTanzSet_gesichert == "success" {
                        Text("TanzSet \"\(neuerTanzSetName)\" erfolgreich gesichert!")
                    }
                    if neuesTanzSet_gesichert == "fail" {
                        Text("Fehler beim Speichern des TanzSets \"\(neuerTanzSetName)\"!")
                    }
                }
                if vorherigeTanzSets != nil {
                    listVorherigeTanzSetsView
                }
            }
        }
    }
    
    var neuerTanzVorschlagView: some View {
       return Section(header: Text("Neuer Tanz Vorschlag")) {
            TextField("Neuer Tanz", text: $newTanz)
                .padding()
                .onSubmit{
//                    Task{
//                        if !newTanz.isEmpty {
//                            let response = await sendNewTanzSuggestion(newTanz: newTanz, organisatorId: UserSession.shared.loggedInUser["UserId"] as! Int)
//                            newTanz_message = response["message"] as! String
                            newTanz = ""
//                        }
//                    }
                    print("jetzt wäre restapi call dran, post \($newTanz)")
                }
            if !newTanz_message.isEmpty {
                Text(newTanz_message)
                
            }
        }
    }
    
    var listOfTogglesView: some View {
        return List {
            ForEach(Array(possibleTänze.keys.sorted(by: >)), id: \.self) { key in
                HStack {
                    Text(key)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { possibleTänze[key] ?? false },
                        set: { newValue in possibleTänze[key] = newValue }
                    ))
                    .labelsHidden() // Versteckt das "Toggle"-Label
                    .onChange(of: possibleTänze[key]!) { _, newValue in
                        if !newValue {
                            tänze.removeAll { $0 == key }
                        } else {
                            if !tänze.contains(key) {
                                tänze.append(key)
                            }
                        }
                    }
                }.padding(15)
            }
        }
    }
    
//    func sendNewTanzSuggestion(newTanz: String, organisatorId: Int) async -> [String: Any] {
//    }
//    
//    func newTanzSetToDatabase(name: String, tanzSet: [String:Bool]) async -> String {
//    }
}

struct TanzSetView: View {
    @Binding var tanzSetName : String
    @Binding var tanzset: [String:Bool]
    
    var body: some View {
        VStack(spacing: 20){
            TextField("Name", text: Binding(
                get: { tanzSetName },
                set: { tanzSetName = $0.isEmpty ? "" : $0 }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .multilineTextAlignment(.center)
            .padding()
            .frame(width: 300)
            
            List {
                ForEach(Array(tanzset.keys.sorted(by: >)), id: \.self) { key in
                    HStack {
                        Text(key)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { tanzset[key] ?? false },
                            set: { newValue in tanzset[key] = newValue }
                        ))
                        .labelsHidden()
                    }.padding(15)
                }
            }
        }
    }
}

struct tanzSetData: Codable {
    var tanzSetName: String
    var tanzset: [String:Bool]
}
