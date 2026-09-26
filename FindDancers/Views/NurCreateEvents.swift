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
    @State private var taenzeAusgeklappt = false
    @State private var isBusy = false
    @State private var statusMeldung: String?
    @State private var fehlermeldung: String?
    @State private var adressStatus: AdressStatus = .unbekannt
    /// Die Adresse, für die zuletzt gesucht wurde. Verhindert, dass beim
    /// Öffnen des Formulars eine gespeicherte, eventuell von Hand verschobene
    /// Pin durch eine erneute Suche überschrieben wird.
    @State private var zuletztGesuchteAdresse: String
    /// Wird nach einem Treffer erhöht, damit die Karte dorthin springt.
    @State private var kartenAnstoss = 0

    enum AdressStatus: Equatable {
        case unbekannt
        case wartet
        case sucht
        case gefunden(String)
        case gefundenOhnePlz(String)
        case nichtGefunden
        case fehler(String)
    }

    init(organizerId: String? = nil) {
        self.organizerId = organizerId
        let geladen = EventFormularStore.shared.laden()
        _entwurf = State(initialValue: geladen)
        _zuletztGesuchteAdresse = State(initialValue: Self.adressSchluessel(geladen.neuerOrt))
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
                datumsAuswahl
//                Text("Ort:")
                ortAuswahl
                taenzeAuswahl
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
        // Hängt am ScrollView statt an einem EmptyView: ein EmptyView rendert
        // nichts, Modifier daran feuern nicht verlässlich.
        .onChange(of: entwurf.typ) { _, neuerTyp in
            belegeKursEndeVor(fuer: neuerTyp)
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

    // MARK: - Datumsauswahl

    /// Bei „Kurs“ wechselt die Datumsauswahl: die beiden Picker beschreiben
    /// dann den **ersten** Termin und darunter kommt das Enddatum der
    /// wöchentlichen Reihe dazu.
    @ViewBuilder
    private var datumsAuswahl: some View {
        let istKurs = entwurf.typ == .Kurs

        DatePicker(istKurs ? "1. Termin" : "Beginn", selection: $entwurf.beginn)
            .padding(.horizontal)
            .frame(width: 350)
        DatePicker(
            istKurs ? "1. Termin Ende" : "Ende",
            selection: $entwurf.ende,
            in: entwurf.beginn...
        )
        .padding(.horizontal)
        .frame(width: 350)

        if istKurs {
            DatePicker(
                "wöchentlich gleich bleibend bis",
                selection: kursEndeAuswahl,
                in: entwurf.beginn...,
                displayedComponents: .date
            )
            .font(.subheadline)
            .padding(.horizontal)
            .frame(width: 350)

            Text(kursReiheZusammenfassung)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    /// Beim Wechsel auf „Kurs“ ein sinnvolles Enddatum vorbelegen, damit der
    /// Picker einen Wert hat. Ein bereits gewähltes Datum bleibt erhalten,
    /// auch wenn zwischenzeitlich ein anderer Typ ausgewählt war.
    private func belegeKursEndeVor(fuer neuerTyp: EventTyp) {
        guard neuerTyp == .Kurs, entwurf.letztes_datum_von_Kurs == nil else { return }
        entwurf.letztes_datum_von_Kurs = Calendar.current.date(
            byAdding: .day,
            value: 7,
            to: entwurf.beginn
        )
    }

    /// Der DatePicker braucht einen nicht-optionalen Wert; solange keiner
    /// gesetzt ist, zeigt er den ersten Termin.
    private var kursEndeAuswahl: Binding<Date> {
        Binding(
            get: { entwurf.letztes_datum_von_Kurs ?? entwurf.beginn },
            set: { entwurf.letztes_datum_von_Kurs = $0 }
        )
    }

    private var kursReiheZusammenfassung: String {
        let termine = entwurf.kursTermine
        guard let letzter = termine.last else {
            return "Enddatum liegt vor dem 1. Termin – es wird ein einzelner Termin angelegt."
        }
        return termine.count == 1
            ? "1 Termin am \(Self.tagesDatum(termine[0].beginn))."
            : "\(termine.count) wöchentliche Termine, letzter am \(Self.tagesDatum(letzter.beginn))."
    }

    /// DD-MM-YYYY, unabhängig von der Gerätesprache. Der DatePicker selbst
    /// zeigt weiterhin das Format der eingestellten Region.
    private static func tagesDatum(_ datum: Date) -> String {
        datum.formatted(
            .verbatim(
                "\(day: .twoDigits)-\(month: .twoDigits)-\(year: .defaultDigits)",
                timeZone: .current,
                calendar: .current
            )
        )
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
                .padding(.horizontal, 24)

            // Paged TabView statt ScrollView mit `scrollPosition`: nur die
            // Selection des TabView stellt beim ersten Layout verlässlich die
            // gespeicherte Seite wieder her.
            TabView(selection: $entwurf.ortModus) {
                bestehenderOrtSeite
                    .tag(OrtModus.bestehenderOrt)
                neuerOrtSeite
                    .tag(OrtModus.neuerOrt)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 540)

            seitenIndikator
        }
        .padding(.vertical)
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
            // „Ortsname“ war unklar: gemeint ist der Name der Location
            // (Venue.name in der EV-API), nicht die Stadt. Das Feld wächst
            // mit dem Text von 1 auf bis zu 5 Zeilen.
            ortFeld(
                "Name der Location, z. B. Tanzsaal Nord",
                text: $entwurf.neuerOrt.name,
                zeilen: 1...5
            )
            ortFeld("Straße & Nr.", text: $entwurf.neuerOrt.streetNr)
            ortFeld("PLZ", text: $entwurf.neuerOrt.zipcode)
                .keyboardType(.numbersAndPunctuation)
            ortFeld("Stadt", text: $entwurf.neuerOrt.city)
            adressStatusZeile
            // Koordinaten werden nicht getippt, sondern über die Karte gesetzt.
            OrtKarteView(
                latitude: $entwurf.neuerOrt.latitude,
                longitude: $entwurf.neuerOrt.longitude,
                zentrierungsAnstoss: kartenAnstoss
            )

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
        // `task(id:)` bricht den laufenden Task bei jeder Änderung ab und
        // startet ihn neu – die Wartezeit beginnt also nach dem letzten
        // Tastendruck von vorn.
        .task(id: adressSchluessel) {
            guard adressSchluessel != zuletztGesuchteAdresse, adressIstSuchbar else { return }
            adressStatus = .wartet
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await geokodiereAdresse()
        }
    }

    /// `zeilen` erlaubt ein mitwachsendes Feld: es beginnt bei der unteren
    /// Grenze und wird bis zur oberen Grenze höher, danach scrollt es intern.
    private func ortFeld(
        _ platzhalter: String,
        text: Binding<String>,
        zeilen: ClosedRange<Int> = 1...1
    ) -> some View {
        TextField(platzhalter, text: text, axis: .vertical)
            .lineLimit(zeilen)
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

    // MARK: - Adresssuche

    /// Straße, PLZ und Stadt als ein Wert – ändert sich einer davon, startet
    /// die Wartezeit neu.
    private var adressSchluessel: String {
        Self.adressSchluessel(entwurf.neuerOrt)
    }

    private static func adressSchluessel(_ ort: NeuerOrtEntwurf) -> String {
        [ort.streetNr, ort.zipcode, ort.city].map(\.trimmed).joined(separator: "|")
    }

    private var adressIstSuchbar: Bool {
        !entwurf.neuerOrt.streetNr.trimmed.isEmpty || !entwurf.neuerOrt.city.trimmed.isEmpty
    }

    @ViewBuilder
    private var adressStatusZeile: some View {
        switch adressStatus {
        case .unbekannt:
            EmptyView()
        case .wartet:
            adressHinweis("Adresse wird in wenigen Sekunden gesucht …", farbe: .secondary)
        case .sucht:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Adresse wird gesucht …").font(.caption2).foregroundStyle(.secondary)
            }
        case .gefunden(let bezeichnung):
            adressHinweis("Gefunden: \(bezeichnung)", farbe: .secondary)
        case .gefundenOhnePlz(let bezeichnung):
            adressHinweis(
                "Gefunden, aber nur ohne die PLZ: \(bezeichnung). Bitte PLZ prüfen "
                + "oder die Pin von Hand setzen.",
                farbe: .orange
            )
        case .nichtGefunden:
            adressHinweis(
                "Keine Adresse gefunden. Schreibweise prüfen oder die Pin von Hand setzen.",
                farbe: .orange
            )
        case .fehler(let grund):
            adressHinweis(grund, farbe: .orange)
        }
    }

    private func adressHinweis(_ text: String, farbe: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(farbe)
            .multilineTextAlignment(.center)
    }

    /// Sucht die eingetippte Adresse und setzt Pin und Kamera auf den Treffer.
    private func geokodiereAdresse() async {
        let strasse = entwurf.neuerOrt.streetNr.trimmed
        let plz = entwurf.neuerOrt.zipcode.trimmed
        let stadt = entwurf.neuerOrt.city.trimmed

        adressStatus = .sucht
        zuletztGesuchteAdresse = adressSchluessel

        do {
            let antwort = try await Geokodierung.suche(strasse: strasse, plz: plz, stadt: stadt)
            guard let treffer = antwort.treffer.first, let koordinate = treffer.koordinate else {
                adressStatus = .nichtGefunden
                return
            }

            entwurf.neuerOrt.latitude = koordinate.latitude
            entwurf.neuerOrt.longitude = koordinate.longitude
            kartenAnstoss += 1
            adressStatus = antwort.plzIgnoriert
                ? .gefundenOhnePlz(treffer.anzeigeName)
                : .gefunden(treffer.anzeigeName)
        } catch {
            adressStatus = .fehler(
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    // MARK: - Tänze

    /// Die Tanzauswahl geht als `taenze` (Tanzname -> Bool) an die EV-API.
    ///
    /// Bewusst ein `DisclosureGroup` mit VStack statt einer `List` wie in
    /// `AddTanzView`: das Formular steckt schon in einem `ScrollView`, eine
    /// verschachtelte `List` würde einen zweiten vertikalen Scrollbereich
    /// aufziehen. Die Zeilen selbst sind identisch aufgebaut.
    private var taenzeAuswahl: some View {
        DisclosureGroup(isExpanded: $taenzeAusgeklappt) {
            VStack(spacing: 0) {
                ForEach(TanzKatalog.namen.sorted(by: >), id: \.self) { tanz in
                    HStack {
                        Text(tanz)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { entwurf.taenze[tanz] ?? false },
                            set: { neuerWert in entwurf.taenze[tanz] = neuerWert }
                        ))
                        .labelsHidden() // Versteckt das "Toggle"-Label
                    }
                    .padding(15)
                    Divider()
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.socialdance")
                Text("Tänze")
                Spacer()
                Text(taenzeZusammenfassung)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private var taenzeZusammenfassung: String {
        let aktive = entwurf.aktiveTaenze
        switch aktive.count {
        case 0: return "keine ausgewählt"
        case 1: return aktive[0]
        default: return "\(aktive.count) ausgewählt"
        }
    }

    // MARK: - EV-API

    private var zeigtFehler: Binding<Bool> {
        Binding(
            get: { fehlermeldung != nil },
            set: { if !$0 { fehlermeldung = nil } }
        )
    }

    /// Legt das Event an: je nach Seite zuerst `POST /Venue`, dann je Termin
    /// `POST /Engagement` plus `PUT /Engagement/{id}/Organizers` und – falls
    /// ein Bild gewählt wurde – `POST /Engagement/{id}/File`.
    ///
    /// Bei einem Kurs mit Enddatum entsteht pro Woche ein eigenes Engagement.
    /// Ort, Name, Beschreibung, Typ und Tänze sind für alle gleich; nur Beginn
    /// und Ende wandern um je sieben Tage weiter. Die Venue wird trotzdem nur
    /// einmal angelegt, und das Bild hängt nur am ersten Termin.
    private func erstelleEngagement() async {
        isBusy = true
        statusMeldung = nil
        defer { isBusy = false }

        // Ohne Reihe bleibt es der eine Termin aus dem Formular.
        let termine = entwurf.kursTermine.isEmpty
            ? [(beginn: entwurf.beginn, ende: entwurf.ende)]
            : entwurf.kursTermine

        var erstellteIds: [String] = []

        do {
            let venueId = try await ermittleVenueId()

            for (nummer, termin) in termine.enumerated() {
                let engagement = try await EVAPIClient.shared.createEngagement(
                    title: entwurf.name.trimmed,
                    start: termin.beginn,
                    end: termin.ende,
                    description: entwurf.beschreibung,
                    venueId: venueId,
                    typ: entwurf.typ,
                    taenze: entwurf.taenze
                )
                erstellteIds.append(engagement.id)

                if let organizerId {
                    try await EVAPIClient.shared.assignOrganizers(
                        engagementId: engagement.id,
                        organizerIds: [organizerId]
                    )
                }

                if nummer == 0 {
                    try await ladeBildHoch(engagementId: engagement.id)
                }

                if termine.count > 1 {
                    statusMeldung = "Termin \(nummer + 1) von \(termine.count) erstellt …"
                }
            }

            statusMeldung = erfolgsMeldung(fuer: erstellteIds)
            verwerfeEntwurf()
        } catch {
            let grund = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            // Bei einer Reihe kann die Hälfte schon auf dem Server liegen –
            // das muss sichtbar sein, sonst legt der Nutzer Dubletten an.
            fehlermeldung = erstellteIds.isEmpty
                ? grund
                : """
                  \(grund)

                  \(erstellteIds.count) von \(termine.count) Terminen wurden \
                  bereits angelegt und bleiben bestehen. Das Formular wird \
                  nicht geleert.
                  """
            statusMeldung = nil
        }
    }

    private func erfolgsMeldung(fuer ids: [String]) -> String {
        guard let ersteId = ids.first else { return "" }
        let titel = entwurf.name.trimmed
        return ids.count == 1
            ? "Event „\(titel)“ erstellt (ID \(ersteId))."
            : "\(ids.count) wöchentliche Termine für „\(titel)“ erstellt."
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
