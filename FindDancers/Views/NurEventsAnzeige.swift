//
//  NurEventsAnzeige.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 07.03.25.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

struct NurEventsAnzeige: View {
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack {
            NavigationStack{
                HStack(spacing: 50) {
                    NavigationLink(destination: danceFilterView()){
                        HStack(spacing: 10){
                            Image(systemName: "figure.socialdance")
                            Text("Tänze")
                        }
                    }
                    NavigationLink(destination: cityFilterView()){
                        HStack(spacing: 10){
                            Image(systemName: "globe.europe.africa")
                            Text("Ort")
                        }
                    }
                    NavigationLink(destination: eventtypeFilterView()){
                        HStack(spacing: 10){
                            Image(systemName: "list.bullet")
                            Text("Events")
                        }
                    }
                }.accentColor(.black)
                ScrollView {
                    NavigationLink(destination: NurParticipantsView()){
                        VStack(spacing: 20){
                            AsyncImage(url: URL(string: "https://jakobblue.com/LonleyDancers/Grafiken/Grafik_67caeae564241.")){ image in
                                image.resizable()
                                    .scaledToFill() // Bild füllt den Rahmen und schneidet überstehende Teile ab
                                    .frame(width: 500, height: 400) // Feste Größe für das Bild
                                    .clipShape(RoundedRectangle(cornerRadius: 15)) // Abgerundeter Rahmen
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 320, height: 320) // Feste Größe für den gesamten Container
                            .clipShape(RoundedRectangle(cornerRadius: 15)) // Stellt sicher, dass auch der Platzhalter passt
                            .padding()
                            
                            Text("Regenbogenball")
                                .font(.title)
                            
                            Text("12.04.2025 20:00 - 22:00")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Beispielstraße 123, 12345 Wien")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing:50){
                                HStack(alignment: .center, spacing: 5){
                                    Image(systemName: "l.square.fill").foregroundStyle(.cyan)
                                    Text("Leaders")
                                }
                                HStack(alignment: .center, spacing: 5){
                                    Image(systemName: "f.square.fill").foregroundColor(.pink.opacity(0.7))
                                    Text("Followers")
                                }
                            }
                            .padding(.vertical, 15)
                            .padding(.horizontal, 10)
                            .font(.system(size: 22).weight(.medium))
                            
                            Button(action: {
                                isExpanded.toggle()
                            }){
                                HStack {
                                    Text("Teilnehmen")
                                        .font(.headline)
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.blue)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.2))) // Hintergrundfarbe für den Button
                                .clipShape(RoundedRectangle(cornerRadius: 10)) // Form bleibt bestehen
                                .tint(.blue) // Farbe für den Button anwenden (z. B. für Text oder Icons)
                            }
                            if isExpanded {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Teilnehmen als")
                                    Button(action: {print("L")}) {
                                        Text("Leader").padding(10)
                                    }.background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.2))) // Hintergrundfarbe für den Button
                                        .clipShape(RoundedRectangle(cornerRadius: 10)) // Form bleibt bestehen
                                        .tint(.blue) // Farbe für den Button anwenden (z. B. für Text oder Icons)
                                    Button(action: {print("F")}) {
                                        Text("Follower").padding(10)
                                    }.background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.2))) // Hintergrundfarbe für den Button
                                        .clipShape(RoundedRectangle(cornerRadius: 10)) // Form bleibt bestehen
                                        .tint(.blue) // Farbe für den Button anwenden (z. B. für Text oder Icons)
                                    Button(action: {print("E")}) {
                                        Text("Egal").padding(10)
                                    }.background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.2))) // Hintergrundfarbe für den Button
                                        .clipShape(RoundedRectangle(cornerRadius: 10)) // Form bleibt bestehen
                                        .tint(.blue) // Farbe für den Button anwenden (z. B. für Text oder Icons)
                                }
                                .padding()
                                .transition(.slide) // Animierter Übergang
                            }
                        }
                        .padding(.horizontal, 100)
                        .background(RoundedRectangle(cornerRadius: 15).fill(.gray.opacity(0.1)).padding(.horizontal, 100))
                    }.tint(.black)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct danceFilterView: View {
    @State private var dances: [String: Bool] = [
        "Wiener Walzer": false,
        "Langsamer Walzer": false,
        "Foxtrott": false,
        "Diskofox": false,
        "Slowfox": false,
        "Quickstepp": false,
        "Jive": false,
        "Rumba": false,
        "Cha Cha Cha": false,
        "Samba": false,
        "Europäischer Tango": false,
        "Argentinescher Tango": false,
        "Salsa": false,
        "Kizomba": false,
        "Bachata": false,
        "Zouk": false,
        "Salsa Mexicana": false,
        "Pachanga": false,
        "West Coast Swing": false
    ]
    var body: some View {
        List {
            ForEach(Array(dances.keys.sorted(by: >)), id: \.self) { key in
                HStack {
                    Text(key)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { dances[key] ?? false },
                        set: { newValue in dances[key] = newValue }
                    ))
                    .labelsHidden() // Versteckt das "Toggle"-Label
                }.padding(15)
            }
        }//.frame(height: CGFloat(Array(dances.keys.sorted(by: >)).count) * CGFloat(self.listRowHeight))
    }
}
struct cityFilterView: View {
    @State private var radius: Double = 50000 // 50 km Umkreis
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        VStack {
            Text("Gegend").font(.title)
            Slider(value: $radius, in: 1000...100000, step: 1000)
                .padding()
            Text("Umkreis: \(Int(radius / 1000)) km")
            Map(position: $locationManager.position) {
                UserAnnotation()
            }
            .edgesIgnoringSafeArea(.all)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .onAppear {
                locationManager.requestLocation()
            }
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Standardwert (San Francisco)
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            DispatchQueue.main.async {
                self.position = .region(
                    MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                )
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Fehler beim Abrufen des Standorts: \(error.localizedDescription)")
    }
}

struct eventtypeFilterView: View {
    @State private var types: [String: Bool] = [
        "Workshop": false,
        "Kurs": false,
        "Veranstaltung": false
    ]
    
    var body: some View {
        List {
            ForEach(Array(types.keys.sorted(by: >)), id: \.self) { key in
                HStack {
                    Text(key)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { types[key] ?? false },
                        set: { newValue in types[key] = newValue }
                    ))
                    .labelsHidden() // Versteckt das "Toggle"-Label
                }.padding(15)
            }
        }
    }
}

#Preview {
    NurEventsAnzeige()
}
