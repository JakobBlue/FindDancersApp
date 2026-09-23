//
//  ImageUploaderView.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 04.03.25.
//


import SwiftUI
import PhotosUI

/// Bildauswahl für ein Event.
///
/// Das gewählte Bild wird sofort über den `EventFormularStore` auf die Platte
/// geschrieben; nach außen gibt die View nur den Dateinamen weiter, den der
/// Aufrufer im Entwurf mitspeichert. Dadurch übersteht die Auswahl einen
/// Tab-Wechsel und einen Neustart der App.
///
/// Der eigentliche Upload passiert nicht hier: `POST /Engagement/{id}/File`
/// braucht eine EngagementId, die es erst nach dem Anlegen des Events gibt.
struct ImageUploaderView: View {
    @Binding var dateiName: String?

    @State private var auswahl: PhotosPickerItem?
    @State private var bild: UIImage?

    var body: some View {
        VStack {
            PhotosPicker(selection: $auswahl, matching: .images) {
                Text(dateiName == nil ? "Bild auswählen" : "Bild ändern")
            }
            .buttonStyle(.bordered)

            if let bild {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)

                Button("Auswahl entfernen") {
                    entferneAuswahl()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
                .padding()
            }
        }
        .onChange(of: auswahl) { _, neueAuswahl in
            Task { await uebernehme(neueAuswahl) }
        }
        .task(id: dateiName) {
            bild = dateiName
                .flatMap { EventFormularStore.shared.bildDaten($0) }
                .flatMap { UIImage(data: $0) }
        }
    }

    private func uebernehme(_ item: PhotosPickerItem?) async {
        guard let item,
              let daten = try? await item.loadTransferable(type: Data.self) else { return }

        let endung = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
        guard let neuerDateiName = EventFormularStore.shared.bildSpeichern(daten, endung: endung) else {
            return
        }

        if let alterDateiName = dateiName {
            EventFormularStore.shared.bildLoeschen(alterDateiName)
        }
        dateiName = neuerDateiName
    }

    private func entferneAuswahl() {
        if let dateiName {
            EventFormularStore.shared.bildLoeschen(dateiName)
        }
        dateiName = nil
        auswahl = nil
        bild = nil
    }
}

#Preview {
    @Previewable @State var dateiName: String?
    ImageUploaderView(dateiName: $dateiName)
}
