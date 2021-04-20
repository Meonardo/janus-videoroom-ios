//
//  JanusRoomManager.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/20.
//

import UIKit

/// 当前仅同时处理一个房间, 切换房间请先调用 `destroy`,  并更改房间号
final class JanusRoomManager {
	
	static let shared = JanusRoomManager()
	
	var roomID: Int = 1234
	
	var roomDisplayName: String = UIDevice.current.name
	
	/// Local Publisher Session ID
	var sessionID: Int64 = 0
	/// Local Publisher Handle ID
	var handleID: Int64 = 0
	/// 当前加入的房间信息, from janus
	var currentRoom: JanusJoinedRoom?
	/// 所有的 Connection, 包含 local connection
	var connections: [JanusConnection] = []
	
	private init() {}
}

extension JanusRoomManager {
	
	func connection(for handleID: Int64) -> JanusConnection? {
		connections.first(where: { $0.handleID == handleID })
	}
	
	func connection(for rtcClient: WebRTCClient) -> JanusConnection? {
		connections.first(where: { $0.rtcClient == rtcClient })
	}
	
	var localConnection: JanusConnection? {
		connection(for: handleID)
	}
	
	func removeLocalConnection() {
		connections.removeAll(where: { $0.handleID == handleID })
	}
	
	/// 重置, 当离开房间后需要调用此方法
	func reset() {
		connections.forEach({ $0.rtcClient?.destory() })
		connections.removeAll()
		sessionID = 0
		handleID = 0
		currentRoom = nil
	}
}
