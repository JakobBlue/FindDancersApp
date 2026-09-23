//
//  OrtKarteView.swift
//  FindDancers
//
//  Setzt latitude/longitude für einen neuen Ort über eine Karte, statt sie
//  eintippen zu lassen.
//

import SwiftUI
import MapKit

/// Karte mit verschiebbarer Pin. Die Pin steht anfangs auf dem aktuellen
/// Standort des Nutzers; Ziehen oder Antippen setzt sie neu. Die Koordinaten
/// landen direkt in den gebundenen Feldern und damit im persistierten Entwurf.
struct OrtKarteView: View {
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    @State private var kamera: MapCameraPosition = .automatic
    /// Nur für die Optik während des Ziehens – die Koordinate wird erst beim
    /// Loslassen gesetzt.
    @State private var ziehVerschiebung: CGSize = .zero
    @State private var laedtStandort = false
    @State private var hinweis: String?

    private var koordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        VStack(spacing: 6) {
            MapReader { proxy in
                Map(position: $kamera) {
                    if let koordinate {
                        Annotation("Veranstaltungsort", coordinate: koordinate) {
                            pin
                                .offset(ziehVerschiebung)
                                .gesture(ziehGeste(proxy: proxy, start: koordinate))
                        }
                        .annotationTitles(.hidden)
                    }
                    UserAnnotation()
                }
                .mapStyle(.standard)
                // Antippen als zweiter Weg, die Pin zu setzen – funktioniert
                // auch dort, wo das Ziehen der Pin schwer zu treffen ist.
                .onTapGesture { punkt in
                    if let neu = proxy.convert(punkt, from: .local) {
                        setzeKoordinate(neu)
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 8) {
                Button {
                    Task { await uebernehmeAktuellenStandort() }
                } label: {
                    Label("Aktueller Standort", systemImage: "location.fill")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
                .disabled(laedtStandort)

                if laedtStandort {
                    ProgressView().controlSize(.small)
                }
            }

            Text(koordinatenText)
                .font(.caption2)
                .foregroundStyle(koordinate == nil ? .orange : .secondary)
                .multilineTextAlignment(.center)

            if let hinweis {
                Text(hinweis)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
        .task {
            // Nur beim ersten Öffnen ohne gespeicherte Position – eine bereits
            // gesetzte Pin wird nicht überschrieben.
            if koordinate == nil {
                await uebernehmeAktuellenStandort()
            } else {
                zeigeAufKarte()
            }
        }
    }

    private var pin: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 32))
            .foregroundStyle(.red, .white)
            .shadow(radius: 2)
            .contentShape(Circle())
    }

    private var koordinatenText: String {
        guard let koordinate else {
            return "Noch keine Position – Pin verschieben, Karte antippen oder „Aktueller Standort“."
        }
        return String(
            format: "Breite %.5f, Länge %.5f – Pin verschieben oder Karte antippen zum Korrigieren.",
            koordinate.latitude,
            koordinate.longitude
        )
    }

    /// Verschiebt die Pin um die gezogene Strecke. Gerechnet wird über den
    /// Bildschirmpunkt der Pin, damit die Pin nach dem Loslassen genau dort
    /// liegt, wo der Finger war.
    private func ziehGeste(proxy: MapProxy, start: CLLocationCoordinate2D) -> some Gesture {
        DragGesture(coordinateSpace: .local)
            .onChanged { wert in
                ziehVerschiebung = wert.translation
            }
            .onEnded { wert in
                defer { ziehVerschiebung = .zero }
                guard let startPunkt = proxy.convert(start, to: .local) else { return }
                let zielPunkt = CGPoint(
                    x: startPunkt.x + wert.translation.width,
                    y: startPunkt.y + wert.translation.height
                )
                if let neu = proxy.convert(zielPunkt, from: .local) {
                    setzeKoordinate(neu)
                }
            }
    }

    /// Setzt nur die Koordinate – die Kamera bleibt, wo der Nutzer sie hat.
    private func setzeKoordinate(_ neu: CLLocationCoordinate2D) {
        latitude = neu.latitude
        longitude = neu.longitude
    }

    private func uebernehmeAktuellenStandort() async {
        laedtStandort = true
        defer { laedtStandort = false }

        do {
            let position = try await StandortDienst.aktuellePosition()
            setzeKoordinate(position)
            hinweis = nil
            zeigeAufKarte()
        } catch {
            hinweis = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func zeigeAufKarte() {
        guard let koordinate else { return }
        withAnimation {
            kamera = .region(
                MKCoordinateRegion(
                    center: koordinate,
                    latitudinalMeters: 600,
                    longitudinalMeters: 600
                )
            )
        }
    }
}

#Preview {
    @Previewable @State var breite: Double? = 49.8728
    @Previewable @State var laenge: Double? = 8.6512
    OrtKarteView(latitude: $breite, longitude: $laenge)
        .padding()
}
