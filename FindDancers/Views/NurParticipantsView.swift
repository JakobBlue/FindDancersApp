//
//  NurParticipantsView.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 08.03.25.
//
//  Description:
//  Was muss das View erfüllen?
//      Verbinden von Leader zu Follower oder von Follower zu Leader,
//      dann sichtbarer MatchRequest, MatchRequest landet in der Inbox des anderen Users
//
//      Jedes Element  NavigationLink(destination: NurParticipantDetailsView())
//


import SwiftUI

struct NurParticipantsView: View {
    var body: some View {
        VStack {
            HStack {
                List {
                    HStack(alignment: .center, spacing: 5){
                        Image(systemName: "l.square.fill").foregroundStyle(.cyan)
                        Text("Leader")
                    }
                    HStack(alignment: .center, spacing: 5){
                        Image(systemName: "l.square.fill").foregroundStyle(.cyan)
                        Text("Leader")
                    }
                    
                }
                List {
                    HStack(alignment: .center, spacing: 5){
                        Image(systemName: "f.square.fill").foregroundColor(.pink.opacity(0.7))
                        Text("Follower")
                    }
                    HStack(alignment: .center, spacing: 5){
                        Image(systemName: "f.square.fill").foregroundColor(.pink.opacity(0.7))
                        Text("Follower")
                    }
                    HStack(alignment: .center, spacing: 5){
                        Image(systemName: "f.square.fill").foregroundColor(.pink.opacity(0.7))
                        Text("Follower")
                    }
                    
                }
            }.frame(height: 500)
            VStack(spacing: 10){
                Text("Deine Anfragen:")
                HStack {
                    Image(systemName: "f.square.fill").foregroundColor(.pink.opacity(0.7)).background(.white)
                    Spacer()
                    Image(systemName: "checkmark")
                }.padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.2))) // Hintergrundfarbe für den Button
                    .clipShape(RoundedRectangle(cornerRadius: 10)) // Form bleibt bestehen
                    .tint(.blue) // Farbe für den Button anwenden (z. B. für Text oder Icons)
                HStack {
                    Image(systemName: "f.square.fill").foregroundColor(.pink.opacity(0.7)).background(.white)
                    Spacer()
                    Text("X")
                }.padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.2))) // Hintergrundfarbe für den Button
                    .clipShape(RoundedRectangle(cornerRadius: 10)) // Form bleibt bestehen
                    .tint(.blue) // Farbe für den Button anwenden (z. B. für Text oder Icons)
                HStack {
                    Image(systemName: "f.square.fill").foregroundColor(.pink.opacity(0.7)).background(.white)
                    Spacer()
                    Image(systemName: "questionmark")
                }.padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.2))) // Hintergrundfarbe für den Button
                    .clipShape(RoundedRectangle(cornerRadius: 10)) // Form bleibt bestehen
                    .tint(.blue) // Farbe für den Button anwenden (z. B. für Text oder Icons)
            }.padding(.top, 20)
                .frame(width: 300)
            Spacer()
        }
    }
}

#Preview {
    NurParticipantsView()
}
