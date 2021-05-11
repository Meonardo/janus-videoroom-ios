//
//  JanusRequests.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/20.
//

import WebRTC

struct JanusCreateRoomSession: Codable {
	var janus = "create"
	var transaction = "Create"
	var room: Int
}

struct JanusLeaveRoom: Codable {
	var janus = "destroy"
	var transaction = "Destroy"
	var session_id: Int64
}

struct JanusAttach: Codable {
	var janus = "attach"
	var session_id: Int64
	var transaction = "Attach"
	var plugin = "janus.plugin.videoroom"
	
	init(id: Int64) {
		self.session_id = id
	}
}

//MARK: - Publisher
struct JanusJoinRoom: Codable {
	
	struct Body: Codable {
		var request = "join"
		var ptype = "publisher"
		var room: Int
        var display: String
	}
	
	var janus = "message"
	var session_id: Int64
	var handle_id: Int64
	var transaction = "JoinRoom"
	var body: Body
	
    init(room: Int, id: Int64, handleID: Int64, display: String) {
		self.session_id = id
		self.handle_id = handleID
        body = Body(room: room, display: display)
	}
}

struct JanusHeatbeat: Codable {
	var janus = "keepalive"
	var session_id: Int64
	var transaction: String = "Heatbeat"
	
	init(id: Int64) {
		session_id = id
	}
}

struct JanusConfigure: Codable {
	
	struct Body: Codable {
		var request = "configure"
		var audio = true
		var video = true
	}
	
	struct Jsep: Codable {
		var type = "offer"
		var sdp: String
	}
	
	var janus = "message"
	var session_id: Int64
	var handle_id: Int64
	var transaction = "Configure"
	var body: Body = Body()
	var jsep: Jsep
	
	init(id: Int64, handleID: Int64, sdp: String) {
		self.session_id = id
		self.handle_id = handleID
		self.jsep = Jsep(sdp: sdp)
	}
}

struct JanusCandidate: Codable {
	
	var janus = "trickle"
	var session_id: Int64
	var handle_id: Int64
	var transaction = "Candidate"
	
	struct Candidate: Codable {
		var candidate: String
		var sdpMid: String
		var sdpMLineIndex: Int32
	}
	
	var candidate: Candidate
	
	init(id: Int64, handleID: Int64, candidate: RTCIceCandidate) {
		self.session_id = id
		self.handle_id = handleID
		self.candidate = Candidate(candidate: candidate.sdp,
								   sdpMid: candidate.sdpMid ?? "",
								   sdpMLineIndex: candidate.sdpMLineIndex)
	}
}

struct JanusUnpublish: Codable {
	
	struct Body: Codable {
		var request = "unpublish"
	}
	
	var janus = "message"
	var session_id: Int64
	var handle_id: Int64
	var transaction = "Unpublish"
	var body: Body = Body()
	
	init(id: Int64, handleID: Int64) {
		self.session_id = id
		self.handle_id = handleID
	}
}

class JanusPublisher: Codable, CustomDebugStringConvertible {
	
	var id: Int64
	var display: String
	var videoCodec: String?
	var audioCodec: String?
	
	required init(from decoder: Decoder) throws {
		videoCodec = try? decoder.decode("video_codec")
		audioCodec = try? decoder.decode("audio_codec")
		id = try decoder.decode("id")
		display = try decoder.decode("display")
	}
	
	init?(dict: [String: Any]) {
		guard let id = dict["id"] as? Int64,
			  let display = dict["display"] as? String else { return nil }
        
		self.videoCodec = dict["video_codec"] as? String
		self.audioCodec = dict["audio_codec"] as? String
		self.display = display
		self.id = id
	}
	
	var description: String {
		"\(display): a-\(audioCodec ?? "null"), v-\(videoCodec ?? "null")"
	}
	
	var debugDescription: String {
		"\(id)-\(description)"
	}
	
	init(id: Int64, display: String) {
		self.id = id
		self.display = display
		videoCodec = ""
		audioCodec = ""
	}
}

class JanusJoinedRoom: Codable, CustomDebugStringConvertible {
	
	var id: Int64 = 1
	var room: Int
	var name: String = "Demo Room"
	var privateID: Int64 = 0
	var publishers: [JanusPublisher] = []
	
	required init(from decoder: Decoder) throws {
		publishers = try decoder.decode(keyPath: "plugindata.data.publishers")
		id = try decoder.decode(keyPath: "plugindata.data.id")
		name = try decoder.decode(keyPath: "plugindata.data.description")
		room = try decoder.decode(keyPath: "plugindata.data.room")
		privateID = try decoder.decode(keyPath: "plugindata.data.private_id")
	}
	
	func publisher(from id: Int64) -> JanusPublisher? {
		publishers.first(where: {$0.id == id })
	}
	
	var debugDescription: String {
		name + ": \(id)"
	}
    
    init?(data: [String: Any]) {
        guard let room = data["room"] as? Int else { return nil }
        
        self.room = room
        self.name = data["display"] as? String ?? ""
        
        guard let participants = data["participants"] as? [[String: Any]] else { return }
        publishers = participants.filter({ ($0["publisher"] as? Bool) == true }).compactMap( { JanusPublisher(dict: $0) })
    }
}

//MARK: - Subscriber

struct JanusSubscribeAttach: Codable {
	var janus = "attach"
	var plugin = "janus.plugin.videoroom"
	var session_id: Int64
	var transaction: String
}

struct JanusSubscribeDetach: Codable {
	var janus = "detach"
	var handle_id: Int64
	var session_id: Int64
	var transaction: String
}

struct JanusSubscribeJoin: Codable {
	
	struct Body: Codable {
		var request = "join"
		var ptype = "subscriber"
		var room: Int
		var feed: Int64
        /// not necessary
//		var private_id: Int64
	}
	
	var body: Body
	var transaction = "SubscribeJoin"
	var janus = "message"
	var session_id: Int64
	var handle_id: Int64
	
	init(room: JanusJoinedRoom, publisher: JanusPublisher, handleID: Int64, sessionID: Int64) {
		body = Body(room: room.room, feed: publisher.id)
		handle_id = handleID
		session_id = sessionID
	}
}

struct JanusSubscribe: Codable {
	
	struct Body: Codable {
		var request = "start"
		var room: Int
	}
	
	struct Jsep: Codable {
		var type = "answer"
		var sdp: String
	}
	
	var transaction = "Subscribe"
	var janus = "message"
	var body: Body
	var jsep: Jsep
	
	init(room: Int, sdp: String) {
		body = JanusSubscribe.Body(room: room)
		jsep = Jsep(sdp: sdp)
	}
}

struct JanusSubscribeStart: Codable {
	
	struct Body: Codable {
		var request = "start"
		var room: Int
	}
	
	struct Jsep: Codable {
		var type = "answer"
		var sdp: String
	}
	
	var janus = "message"
	var transaction = "Start"
	var body: Body
	var jsep: Jsep
	var handle_id: Int64
	var session_id: Int64
	
	init(room: Int, sdp: String, handleID: Int64, sessionID: Int64) {
		self.body = Body(room: room)
		self.jsep = Jsep(sdp: sdp)
		session_id = sessionID
		handle_id = handleID
	}
}

struct JanusListparticipants: Codable {
    
    struct Body: Codable {
        var request = "listparticipants"
        var room: Int
    }
    var janus = "message"
    var transaction = "Listparticipants"
    var session_id: Int64
    var handle_id: Int64
    var body: Body
    
    init(room: Int, sessionID: Int64, handleID: Int64) {
        session_id = sessionID
        handle_id = handleID
        body = Body(room: room)
    }
}
