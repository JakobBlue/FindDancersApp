//
//  MatchAnfrageView.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 23.03.25.
//

import SwiftUI

struct MatchAnfrageView: View {
    @State private var isExpanded = false
    let requests: [MatchRequest] = []
    
    func agreeRequest(_ request: MatchRequest) {
        //insert into matches
    }
    
    var body: some View {
        NavigationStack {
            NavigationLink(destination: NurParticipantsView()){
                VStack{
                 
                    infosAndImageView
                    howManyParticipantsView
                    teilnehmenView
                    requestTextView
                    agree_and_disagreeView
                }.frame(width: 350)
                .padding(.horizontal, 100)
                .background(RoundedRectangle(cornerRadius: 15).fill(.gray.opacity(0.1)).padding(.horizontal, 100))
            }.tint(.black)
        }
    }
    
    var infosAndImageView: some View {
        return VStack(spacing: 20) {
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
        }
    }
    
    var howManyParticipantsView: some View {
        return VStack(spacing:20){
            HStack(){
                HStack(alignment: .center, spacing: 5){
                    Image(systemName: "l.square.fill").foregroundStyle(.cyan)
                    Text("Leaders")
                }
                Spacer()
                HStack(alignment: .center, spacing: 5){
                    Image(systemName: "f.square.fill").foregroundColor(.pink.opacity(0.7))
                    Text("Followers")
                }
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 5)
            .font(.system(size: 22).weight(.medium))
            .frame(width: 300)
        }
    }
    
    var teilnehmenView: some View {
        return VStack(spacing: 20){
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
    }
    
    var requestTextView: some View {
        return VStack(spacing:20) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Julia möchte mit dir als")
                Text(" ")
                Image(systemName: "l.square.fill").foregroundStyle(.cyan)
                Text(" ")
                Text("Leader tanzen üben")
            }.padding()
            .frame(width: 330)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .padding(.bottom)
            .font(.footnote)
//            HStack {
//                Text("Julia möchte mit dir als ")
//                HStack(alignment: .center, spacing: 5){
//                    Image(systemName: "l.square.fill").foregroundStyle(.cyan)
//                    Text("Leader")
//                }
//                Text("tanzen üben")
//            }.padding() // Abstand zwischen Inhalt und Rand
//                .frame(width: 300)
//                .background(Color.white) // Hintergrund, damit die Rundung sichtbar ist
//                .cornerRadius(10) // Abgerundete Ecken
//                .overlay(
//                    RoundedRectangle(cornerRadius: 10)
//                        .stroke(Color.gray, lineWidth: 1) // Border hinzufügen
//                )
//                .padding(.bottom) // Äußerer Abstand nach unten
//                .font(.footnote)
        }
    }
    
    var agree_and_disagreeView: some View {
        return VStack(spacing:20){
            HStack {
                Button(action: {print("Ja")}) {
                    Text("Annehmen").padding(10)
                }.background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.2)))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .tint(.green)
                Spacer().frame(width: 20)
                Button(action: {print("Ja")}) {
                    Text("Ablehnen").padding(10)
                }.background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.2)))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .tint(.red)
            }.padding(.bottom)
        }
    }
}

#Preview {
    MatchAnfrageView()
}
