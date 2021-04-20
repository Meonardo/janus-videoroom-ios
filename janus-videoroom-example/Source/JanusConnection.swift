//
//  JanusConnection.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/20.
//

import Foundation
import WebRTC

class JanusConnection: Equatable {
	
	var handleID: Int64
	/// 订阅的发布者信息
	var publisher: JanusPublisher
	
	var rtcClient: WebRTCClient?
	
	required init(handleID: Int64, publisher: JanusPublisher) {
		self.handleID = handleID
		self.publisher = publisher
	}
	
	static func == (lhs: JanusConnection, rhs: JanusConnection) -> Bool {
		lhs.handleID == rhs.handleID
	}
	
	var isLocal: Bool {
		handleID == JanusRoomManager.shared.handleID
	}
}
