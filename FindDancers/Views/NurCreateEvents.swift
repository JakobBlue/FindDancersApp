//
//  NurCreateEvents.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 05.03.25.
//

import SwiftUI

struct NurCreateEvents: View {
    @State private var selectedTyp: Typ = .Workshop
    
    enum Typ: String, CaseIterable, Identifiable {
        case Workshop, Kurs, Veranstaltung
        
        var id: Self { self }
    }
    
    var body: some View {
        ScrollView {
            Text("MüllerMerkt")
            Spacer()
            VStack() {
                NavigationStack {  // NavigationView hilft oft, Picker sichtbar zu machen
                    Form {  // Form statt List für eine bessere Darstellung von Pickern
                        Picker("Event Typ", selection: $selectedTyp) {
                            ForEach(Typ.allCases) { typ in
                                Text(typ.rawValue).tag(typ)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())  // Alternative: .inline oder .segmented
                    }
                }.frame(height: 100)
                    .onChange(of: selectedTyp) { _, newValue in
                        print(newValue)
                    }
//                Text("Eventname:")
                TextField("Name", text: .constant(""))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                   .padding()
                                   .frame(width: 300)
//                Text("Eventbeschreibung:")
                TextField("Beschreibung", text: .constant(""))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                   .padding()
                                   .frame(width: 300)
//                Text("Datum:")
                TextField("Datum", text: .constant(""))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .frame(width: 300)
//                Text("Ort:")
                TextField("Ort", text: .constant(""))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .frame(width: 300)
              //  ImageUploaderView(kontext: GrafikKontext(Typ: selectedTyp.rawValue, Fremdschlüssel: 1))
                Button(action: {
                    
                }) {
                    Text("Event erstellen")
                }.buttonStyle(.bordered)
//                an example for quick web image testing
//                AsyncImage(url: URL(string: "https://jakobblue.com/LonleyDancers/Grafiken/Grafik_67c97b1ec9752."), scale: 15)
                    .padding()
            }.background(Color.gray.opacity(0.1))
        }
    }
}

#Preview {
    NurCreateEvents()
}
