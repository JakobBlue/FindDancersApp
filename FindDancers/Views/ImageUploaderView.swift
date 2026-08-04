//
//  ImageUploaderView.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 04.03.25.
//


import SwiftUI
import PhotosUI

struct ImageUploaderView: View {
    @Binding var selectedImage: UIImage? // Bild speichern
    @Binding var selectedItem: PhotosPickerItem? // Für Metadaten
    @State private var imageData: Data? // Bild-Daten speichern
    var kontext: GrafikKontext
    var showUploadButton: Bool // Neuer Parameter
    
    var body: some View {
        VStack {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text("Bild auswählen")
            }.buttonStyle(.bordered)
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let newItem = newItem,
                       let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                        imageData = data
                    }
                }
            }

            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                
            }

            if (selectedImage == nil) {
                Button("Auswahl entfernen") {
                   
                }.buttonStyle(.bordered)
                .foregroundStyle(.gray)
                .padding()
            } else {
                Button("Auswahl entfernen") {
                    selectedImage = nil
                    selectedItem = nil
                    imageData = nil
                }.buttonStyle(.bordered)
                    .foregroundStyle(.red)
                    .padding()
                    .disabled((selectedImage == nil))                
            }
            
            // Upload-Button nur anzeigen, wenn `showUploadButton` true ist
            if showUploadButton {
                Button("Upload starten") {
                    if selectedImage != nil, selectedItem != nil {
//                         uploadImage(image: image, item: item)
                        print("hier wäre der Upload, rest api call post file")
                    }
                }
                .buttonStyle(.bordered)
                .padding()
                .disabled(selectedImage == nil)
            }
            
        }
    }

    func getRandomGrafikName() -> String {
        //muss geändert werden zu
        //sql select all names von grafiken
        // generiere neue id und prüfe dass id nicht schon vorkommt
        let randomIndex = Int.random(in: 0..<100)
        return "Grafik_getRandomGrafikName_\(randomIndex).jpg"
    }
    
//    func uploadImage(image: UIImage, item: PhotosPickerItem) {
//    }

//    func startUpload(filename: String, mimeType: String, imageData: Data) {
//    }
    
    func getMimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
            case "jpg", "jpeg": return "image/jpeg"
            case "png": return "image/png"
            case "heic": return "image/heic"
            default: return "application/octet-stream" // Fallback für unbekannte Typen
        }
    }

}
