//
//  NurParticipantDetailsView.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 08.03.25.
//

import SwiftUI

struct NurParticipantDetailsView: View {
    var body: some View {
        VStack{
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
                Text("franziska berberig")
                Button("Tanze mit Franzi als Follower"){
                    
                }.buttonStyle(.borderedProminent).tint(.green).font(.system(size: 22).weight(.medium))/*.frame(width: 1000, height: 50)*/
            }.padding(.horizontal, 100)
                .background(RoundedRectangle(cornerRadius: 15).fill(.gray.opacity(0.1)).padding(.horizontal, 100))
            Spacer()
        }
    }
}

#Preview {
    NurParticipantDetailsView()
}
