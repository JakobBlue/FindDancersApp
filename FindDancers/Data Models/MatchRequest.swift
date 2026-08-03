//
//  MatchRequest.swift
//  LonelyDancers1
//
//  Created by Jakob Tobias Weitzel on 24.03.25.
//
//
//erstellungsdatum
//event_id
//event_typ
//id
//role_of_requester
//who_received
//who_requested

import Foundation

struct MatchRequest: Codable {
    var id: Int
    var eventId: Int
    var eventTyp: String
    var roleOfRequester: String
    var whoReceived: Int
    var whoRequested: Int
}
