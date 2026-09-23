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
    var organizerId: String?

    /// Der gesamte Formularzustand. Jede Änderung wird sofort weggeschrieben,
    /// siehe `EventFormularStore`.
    @State private var entwurf: EventFormularEntwurf
    @State private var verfuegbareOrte: [EVVenue] = []
    @State private var isBusy = false
    @State private var statusMeldung: String?
    @State private var fehlermeldung: String?

    init(organizerId: String? = nil) {
        self.organizerId = organizerId
        _entwurf = State(initialValue: EventFormularStore.shared.laden())
    }

    private var isFormValid: Bool {
        guard !entwurf.name.trimmed.isEmpty, entwurf.ende >= entwurf.beginn else { return false }
        switch entwurf.ortModus {
        case .bestehenderOrt:
            return true
        case .neuerOrt:
            // Entweder gar kein neuer Ort oder ein vollständiger.
            return entwurf.neuerOrt.istLeer || entwurf.neuerOrt.istVollstaendig
        }
    }

    var body: some View {
        ScrollView {
            Text("MüllerMerkt")
            Spacer()
            VStack() {
                NavigationStack {  // NavigationView hilft oft, Picker sichtbar zu machen
                    Form {  // Form statt List für eine bessere Darstellung von Pickern
                        Picker("Event Typ", selection: $entwurf.typ) {
                            ForEach(EventTyp.allCases) { typ in
                                Text(typ.rawValue).tag(typ)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())  // Alternative: .inline oder .segmented
                    }
                }.frame(height: 100)
//                Text("Eventname:")
                TextField("Name", text: $entwurf.name)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                   .padding()
                                   .frame(width: 300)
//                Text("Eventbeschreibung:")
                TextField("Beschreibung", text: $entwurf.beschreibung)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                   .padding()
                                   .frame(width: 300)
//                Text("Datum:")
                DatePicker("Beginn", selection: $entwurf.beginn)
                    .padding(.horizontal)
                    .frame(width: 320)
                DatePicker("Ende", selection: $entwurf.ende, in: entwurf.beginn...)
                    .padding(.horizontal)
                    .frame(width: 320)
//                Text("Ort:")
                ortAuswahl
                ImageUploaderView(dateiName: $entwurf.bildDateiname)
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
        .onChange(of: entwurf) { _, neuerEntwurf in
            EventFormularStore.shared.speichern(neuerEntwurf)
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

    // MARK: - Ortsauswahl

    /// Zwei Seiten, zwischen denen horizontal gewischt wird. Der aktive Modus
    /// steckt im Entwurf und wird damit ebenfalls persistiert – nach einem
    /// Neustart öffnet sich wieder dieselbe Seite. Die Eingaben beider Seiten
    /// bleiben beim Wechseln erhalten, weil beide Seiten in denselben Entwurf
    /// schreiben und nie zurückgesetzt werden.
    private var ortAuswahl: some View {
        VStack(spacing: 8) {
            Text(entwurf.ortModus.titel)
                .font(.subheadline.weight(.semibold))
            Text("Horizontal wischen, um zwischen bestehendem und neuem Ort zu wechseln.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    bestehenderOrtSeite
                        .containerRelativeFrame(.horizontal)
                        .id(OrtModus.bestehenderOrt)
                    neuerOrtSeite
                        .containerRelativeFrame(.horizontal)
                        .id(OrtModus.neuerOrt)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: sichtbarerOrtModus)
            .frame(height: 340)

            seitenIndikator
        }
        .padding(.vertical)
    }

    /// `scrollPosition` meldet die gewischte Seite hier zurück und scrollt
    /// umgekehrt zur gespeicherten Seite, wenn das Formular geladen wird.
    private var sichtbarerOrtModus: Binding<OrtModus?> {
        Binding(
            get: { entwurf.ortModus },
            set: { neuerModus in
                if let neuerModus, neuerModus != entwurf.ortModus {
                    entwurf.ortModus = neuerModus
                }
            }
        )
    }

    private var bestehenderOrtSeite: some View {
        VStack(spacing: 12) {
            // Ein Engagement verweist per `venueId` auf eine bestehende Venue.
            Picker("Ort", selection: $entwurf.bestehenderOrtId) {
                Text("Kein Ort").tag(String?.none)
                ForEach(verfuegbareOrte) { ort in
                    Text(ortBeschreibung(ort)).tag(String?.some(ort.id))
                }
            }
            .pickerStyle(.menu)

            if verfuegbareOrte.isEmpty {
                Text("Noch keine Orte in der EV-API hinterlegt – nach rechts wischen, um einen anzulegen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var neuerOrtSeite: some View {
        VStack(spacing: 8) {
            ortFeld("Ortsname", text: $entwurf.neuerOrt.name)
            ortFeld("Straße & Nr.", text: $entwurf.neuerOrt.streetNr)
            ortFeld("PLZ", text: $entwurf.neuerOrt.zipcode)
                .keyboardType(.numbersAndPunctuation)
            ortFeld("Stadt", text: $entwurf.neuerOrt.city)
            ortFeld("Breitengrad, z. B. 49.8728", text: $entwurf.neuerOrt.latitude)
                .keyboardType(.numbersAndPunctuation)
            ortFeld("Längengrad, z. B. 8.6512", text: $entwurf.neuerOrt.longitude)
                .keyboardType(.numbersAndPunctuation)

            if !entwurf.neuerOrt.istLeer && !entwurf.neuerOrt.istVollstaendig {
                // Die EV-API lehnt eine Venue mit fehlenden Feldern ab.
                Text("Noch offen: \(entwurf.neuerOrt.fehlendeFelder.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func ortFeld(_ platzhalter: String, text: Binding<String>) -> some View {
        TextField(platzhalter, text: text)
            .multilineTextAlignment(.center)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .textInputAutocapitalization(.words)
    }

    private var seitenIndikator: some View {
        HStack(spacing: 6) {
            ForEach(OrtModus.allCases) { modus in
                Capsule()
                    .fill(modus == entwurf.ortModus ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: modus == entwurf.ortModus ? 18 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: entwurf.ortModus)
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

    /// Legt das Event an: je nach Seite zuerst `POST /Venue`, dann
    /// `POST /Engagement`, `PUT /Engagement/{id}/Organizers` und – falls ein
    /// Bild gewählt wurde – `POST /Engagement/{id}/File`.
    private func erstelleEngagement() async {
        isBusy = true
        statusMeldung = nil
        defer { isBusy = false }

        do {
            let venueId = try await ermittleVenueId()

            let engagement = try await EVAPIClient.shared.createEngagement(
                title: entwurf.name.trimmed,
                start: entwurf.beginn,
                end: entwurf.ende,
                description: entwurf.beschreibung,
                venueId: venueId
            )

            if let organizerId {
                try await EVAPIClient.shared.assignOrganizers(
                    engagementId: engagement.id,
                    organizerIds: [organizerId]
                )
            }

            try await ladeBildHoch(engagementId: engagement.id)

            statusMeldung = "Event „\(engagement.title ?? entwurf.name)“ erstellt (ID \(engagement.id))."
            verwerfeEntwurf()
        } catch {
            fehlermeldung = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func ermittleVenueId() async throws -> String? {
        switch entwurf.ortModus {
        case .bestehenderOrt:
            return entwurf.bestehenderOrtId
        case .neuerOrt:
            guard let anfrage = entwurf.neuerOrt.anfrage else { return nil }
            let neueVenue = try await EVAPIClient.shared.createVenue(anfrage)
            verfuegbareOrte.append(neueVenue)
            return neueVenue.id
        }
    }

    private func ladeBildHoch(engagementId: String) async throws {
        guard let bildDateiname = entwurf.bildDateiname,
              let daten = EventFormularStore.shared.bildDaten(bildDateiname) else { return }

        try await EVAPIClient.shared.attachFile(
            engagementId: engagementId,
            dateiName: bildDateiname,
            mimeTyp: EventFormularStore.shared.mimeTyp(fuer: bildDateiname),
            daten: daten
        )
    }

    /// Erst nach erfolgreichem Anlegen wird das Formular geleert – der neue,
    /// leere Entwurf wird über `onChange` sofort persistiert.
    private func verwerfeEntwurf() {
        if let bildDateiname = entwurf.bildDateiname {
            EventFormularStore.shared.bildLoeschen(bildDateiname)
        }
        entwurf = EventFormularEntwurf()
    }
}

#Preview {
    NurCreateEvents()
}
