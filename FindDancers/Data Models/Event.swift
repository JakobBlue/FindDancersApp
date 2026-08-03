//
//  Event.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 20.03.25.
//
import Foundation

struct Event: Identifiable {
    var id: Int
    var eventGrafikURL: String
    var eventTyp: String
    var eventName: String
    var eventDate: Date
    var eventStartTime: String
    var eventEndTime: String
    var eventLocation: String
    var eventMaxPaare: Int?
    var eventTanz: [String:Bool]
    var eventOrganisatorID: Int
    var eventBeschreibung: String?
    var isExpanded: Bool
}
