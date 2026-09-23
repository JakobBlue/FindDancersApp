//
//  NurCreateEvents.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 05.03.25.
//

import SwiftUI

struct NurCreateEvents: View {
    /// `OrganizerId` des angemeldeten Organisators. Ist sie vorhanden, wird das
    /// neue Engagement per `PUT /Engagement/{id}/Organizers` zugeordnet.
    var organizerId: String? = nil

    @State private var selectedTyp: Typ = .Workshop
    @State private var eventName = ""
    @State private var eventBeschreibung = ""
    @State private var eventBeginn = Date()
    @State private var eventEnde = Date().addingTimeInterval(2 * 60 * 60)
    @State private var verfuegbareOrte: [EVVenue] = []
    @State private var ausgewaehlteOrtId: String? = nil
    @State private var isBusy = false
    @State private var statusMeldung: String?
    @State private var fehlermeldung: String?

    enum Typ: String, CaseIterable, Identifiable {
        case Workshop, Kurs, Veranstaltung

        var id: Self { self }
    }

    private var isFormValid: Bool {
        !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && eventEnde >= eventBeginn
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
                TextField("Name", text: $eventName)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                   .padding()
                                   .frame(width: 300)
//                Text("Eventbeschreibung:")
                TextField("Beschreibung", text: $eventBeschreibung)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                   .padding()
                                   .frame(width: 300)
//                Text("Datum:")
                DatePicker("Beginn", selection: $eventBeginn)
                    .padding(.horizontal)
                    .frame(width: 320)
                DatePicker("Ende", selection: $eventEnde, in: eventBeginn...)
                    .padding(.horizontal)
                    .frame(width: 320)
//                Text("Ort:")
                // Ein Engagement verweist per `venueId` auf eine bestehende Venue,
                // deshalb Auswahl statt Freitext.
                Picker("Ort", selection: $ausgewaehlteOrtId) {
                    Text("Kein Ort").tag(String?.none)
                    ForEach(verfuegbareOrte) { ort in
                        Text(ortBeschreibung(ort)).tag(String?.some(ort.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                .frame(width: 320)
                if verfuegbareOrte.isEmpty {
                    Text("Noch keine Orte in der EV-API hinterlegt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
              //  ImageUploaderView(kontext: GrafikKontext(Typ: selectedTyp.rawValue, Fremdschlüssel: 1))
                Button(action: {
                    Task { await erstelleEngagement() }
                }) {
                    Text("Event erstellen")
                }.buttonStyle(.bordered)
                    .disabled(!isFormValid || isBusy)
                    .padding()
                if isBusy {
                    ProgressView()
                }
                if let statusMeldung {
                    Text(statusMeldung)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
//                an example for quick web image testing
//                AsyncImage(url: URL(string: "https://jakobblue.com/LonleyDancers/Grafiken/Grafik_67c97b1ec9752."), scale: 15)
            }.background(Color.gray.opacity(0.1))
        }
        .task {
            verfuegbareOrte = (try? await EVAPIClient.shared.venues()) ?? []
        }
        .alert("Event konnte nicht erstellt werden", isPresented: zeigtFehler) {
            Button("OK", role: .cancel) { fehlermeldung = nil }
        } message: {
            Text(fehlermeldung ?? "")
        }
    }

    private func ortBeschreibung(_ ort: EVVenue) -> String {
        [ort.name, ort.city].compactMap { $0 }.joined(separator: ", ")
    }

    // MARK: - EV-API

    private var zeigtFehler: Binding<Bool> {
        Binding(
            get: { fehlermeldung != nil },
            set: { if !$0 { fehlermeldung = nil } }
        )
    }

    /// Erstellt ein Engagement über `POST /Engagement` und ordnet es
    /// anschließend dem angemeldeten Organisator zu.
    private func erstelleEngagement() async {
        let titel = eventName.trimmingCharacters(in: .whitespacesAndNewlines)

        isBusy = true
        statusMeldung = nil
        defer { isBusy = false }

        do {
            let engagement = try await EVAPIClient.shared.createEngagement(
                title: titel,
                start: eventBeginn,
                end: eventEnde,
                description: eventBeschreibung,
                venueId: ausgewaehlteOrtId
            )

            if let organizerId {
                try await EVAPIClient.shared.assignOrganizers(
                    engagementId: engagement.id,
                    organizerIds: [organizerId]
                )
            }

            statusMeldung = "Event „\(engagement.title ?? titel)“ erstellt (ID \(engagement.id))."
            eventName = ""
            eventBeschreibung = ""
        } catch {
            fehlermeldung = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#Preview {
    NurCreateEvents()
}
