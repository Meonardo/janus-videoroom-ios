//
//  WebSocketSignalingClient.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/20.
//

import Foundation
import Starscream
import WebRTC

protocol WebSocketSignalingClientDelegate: class {
	
	func signalingClientDidConnect()
	func signalingClientDidDisconnect()
	
	func signalingClient(didReceiveMessage msg: String)
	
	func signalingClient(didReceiveRemoteSdp sdp: RTCSessionDescription, handleID: Int64)
	func signalingClient(didReceiveCandidate candidate: RTCIceCandidate)
	
	func signalingClient(didAttach handleID: Int64, sessionID: Int64)
	func signalingClient(didJoinRoom room: JanusJoinedRoom)
	func signalingClient(didLeaveRoom room: JanusJoinedRoom)
	func signalingClient(didSubscribeAttach handleID: Int64, publisher: JanusPublisher)
}

extension WebSocketSignalingClientDelegate {
	func signalingClient(didReceiveMessage msg: String) {}
	func signalingClient(didReceiveCandidate candidate: RTCIceCandidate) {}
}

/// Notifications
extension WebSocketSignalingClient {
	/// Object: [String: Any] , contains: handleID & hangup reason
	static var didReciveLeaveNotification = Notification.Name("kDidReciveLeaveNotification")
	/// Object: `JanusConnection`
	static var didStartSubscribingNewPublisherNotification = Notification.Name("kDidStartSubscribingNewPublisherNotification")
}

class WebSocketSignalingClient {

	var delegate: WebSocketSignalingClientDelegate?
	
	private var timer: Foundation.Timer?
	private let socket: WebSocket
	
	private let roomManager = JanusRoomManager.shared
	
	private lazy var encoder: JSONEncoder = {
		return JSONEncoder()
	}()
	
	private lazy var decoder: JSONDecoder = {
		return JSONDecoder()
	}()
	
	init(url: URL) {
		var request = URLRequest(url: url)
		let protocols = ["janus-protocol"]
		request.setValue(protocols.joined(separator: ","), forHTTPHeaderField: "Sec-WebSocket-Protocol")
		socket = WebSocket(request: request)
		socket.delegate = self
	}
	
	/// Connect WebSocket Server
	func connect() {
		socket.connect()
	}
	
	/// Disconnect WebSocket Server
	func disconnect() {
		socket.disconnect()
	}
	
	/// Writer WebScoket Message
	func write(data: Data) {
		let msg = String(data: data, encoding: .utf8) ?? ""
		print("==============> Send WebSocket Message: \(msg) \n")
		socket.write(data: data)
	}
}

/// Timers & Keep alive
extension WebSocketSignalingClient {

	private func configureTimer() {
		if timer != nil {
			return
		}
		let timer = Foundation.Timer(timeInterval: 20, repeats: true) { [weak self] (t) in
			self?.sendHeatbeat()
		}
		RunLoop.current.add(timer, forMode: .common)
		timer.fire()
		self.timer = timer
	}
	
	private func killTimer() {
		if timer != nil {
			timer?.invalidate()
			timer = nil
		}
	}
}

/// Janus Requests
extension WebSocketSignalingClient {
	/// 加入房间
	/// - Parameter roomID: 房间号
	func createRoom(roomID: Int) {
		let req = JanusCreateRoom(room: roomID)
		do {
			let msg = try encoder.encode(req)
			write(data: msg)
		} catch {
			debugPrint("Warning: Could not encode Join Request: \(error)")
		}
	}
	
	/// 离开房间
	func leaveRoom() {
		killTimer()
		let sessionID = roomManager.sessionID
		let req = JanusLeaveRoom(session_id: sessionID)
		do {
			let msg = try encoder.encode(req)
			write(data: msg)
		} catch {
			debugPrint("Warning: Could not encode Join Request: \(error)")
		}
	}
	
	/// 发送心跳包, keep-alive
	private func sendHeatbeat() {
		let req = JanusHeatbeat(id: roomManager.sessionID)
		do {
			let msg = try encoder.encode(req)
			write(data: msg)
		} catch {
			print(error.localizedDescription)
		}
	}
	
	/// Attach, 作为发布者身份加入房间时获取 handle_id
	private func sendAttachRequest(id: Int64) {
		roomManager.sessionID = id
		let req = JanusAttach(id: id)
		do {
			let msg = try encoder.encode(req)
			write(data: msg)
		} catch {
			print(error.localizedDescription)
		}
	}
	
	/// 加入房间 as a Publisher
	private func sendJoinRoomRequest(id: Int64, handleID: Int64) {
		roomManager.handleID = handleID
		let req = JanusJoinRoom(id: id, handleID: handleID)
		do {
			let msg = try encoder.encode(req)
			write(data: msg)
		} catch {
			print(error.localizedDescription)
		}
	}
	
	/// 发布
	func publish() {
		let handleID = roomManager.handleID
		let id = roomManager.sessionID
		sendJoinRoomRequest(id: id, handleID: handleID)
	}
	
	/// 取消发布
	func unpublish() {
		let req = JanusUnpublish(id: roomManager.sessionID, handleID: roomManager.handleID)
		do {
			let msg = try encoder.encode(req)
			write(data: msg)
		} catch {
			print(error.localizedDescription)
		}
	}
	
	/// Attach 发布者
	func attach(publisher: JanusPublisher) {
		do {
			let transaction = "Attach.\(publisher.id)"
			let attach = JanusSubscribeAttach(session_id: roomManager.sessionID, transaction: transaction)
			let attachMsg = try encoder.encode(attach)
			write(data: attachMsg)
		} catch {
			print(error.localizedDescription)
		}
	}
	
	/// 订阅发布者
	func sendSubscribeRequest(room: JanusJoinedRoom, publisher: JanusPublisher, handleID: Int64) {
		let req = JanusSubscribeJoin(room: room, publisher: publisher, handleID: handleID, sessionID: roomManager.sessionID)
		do {
			let msg = try encoder.encode(req)
			write(data: msg)
		} catch {
			print(error.localizedDescription)
		}
	}
	
	func sendOffer(sdp: String, isConfiguration: Bool) {
		let req = JanusConfigure(id: roomManager.sessionID, handleID: roomManager.handleID, sdp: sdp)
		do {
			let msg = try encoder.encode(req)
			write(data: msg)
		} catch {
			print(error.localizedDescription)
		}
	}
	
	func sendAnswer(sdp: String, handleID: Int64) {
		let req = JanusSubscribeStart(room: roomManager.roomID, sdp: sdp, handleID: handleID, sessionID: roomManager.sessionID)
		do {
			let msg = try encoder.encode(req)
			write(data: msg)
		} catch {
			print(error.localizedDescription)
		}
	}
	
	func send(candidate: RTCIceCandidate, handleID: Int64) {
		let req = JanusCandidate(id: roomManager.sessionID, handleID: handleID, candidate: candidate)
		do {
			let msg = try encoder.encode(req)
			write(data: msg)
		} catch {
			print(error.localizedDescription)
		}
	}
}

/// WebSocketDelegate
extension WebSocketSignalingClient: WebSocketDelegate {
	
	func didReceive(event: WebSocketEvent, client: WebSocket) {
		switch event {
		case .connected:
			delegate?.signalingClientDidConnect()
		case .disconnected:
			delegate?.signalingClientDidDisconnect()
			DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
				self.connect()
			}
		case .text(let text):
			processReceivedMessage(text: text)
		case .binary:
			break
		case .ping:
			break
		case .pong:
			break
		case .viabilityChanged:
			break
		case .reconnectSuggested:
			break
		case .cancelled:
			break
		case .error(let error):
			print("WebSocket Error: \(error?.localizedDescription ?? "")")
		}
	}
}

/// Procesing
extension WebSocketSignalingClient {
	
	private func processReceivedMessage(text: String) {
		print("<============== Receive WebSocket Message: \(text) \n")
		
		guard let source = text.data(using: .utf8) else {
			print("!Process Data -> String Error!")
			return
		}
		
		do {
			let obj = try JSONSerialization.jsonObject(with: source, options: [])
			guard let data = obj as? [String: Any] else { return }
	
			if let aData = data["data"] as? [String: Any] {
				let transaction = data["transaction"] as? String ?? ""
				if let id = aData["id"] as? Int64 {
					if transaction == "Create" {
						/// 创建成功, 获得 session_id
						sendAttachRequest(id: id)
					} else if transaction == "Attach" {
						/// 获得 handle_id
						delegate?.signalingClient(didAttach: id, sessionID: roomManager.sessionID)
						sendJoinRoomRequest(id: roomManager.sessionID, handleID: id)
					} else if transaction.hasPrefix("Attach.") {
						/// Attached 成功
						guard let last = transaction.components(separatedBy: ".").last, let publisherID = Int64(last) else { return }
						guard let room = roomManager.currentRoom, let publisher = room.publisher(from: publisherID) else { return }
						
						delegate?.signalingClient(didSubscribeAttach: id, publisher: publisher)
						
						sendSubscribeRequest(room: room, publisher: publisher, handleID: id)
					}
				}
			} else {
				if let janus = data["janus"] as? String {
					if janus == "error" {
						guard let error = data["error"] as? [String: Any] else { return }
						print("error: \(error["reason"] ?? "no reason")")
					} else {
						/// success
						let transaction = data["transaction"] as? String ?? ""
						if transaction == "JoinRoom" {
							processJoinedRoom(data: source)
						} else if transaction == "Configure" {
							processConfigures(data: data)
						} else if transaction == "SubscribeJoin" {
							processOffer(data: data)
						} else if transaction == "Candidate" {

						} else if transaction == "Start" {
							processSubscribeStarted(data: data)
						} else if transaction == "Destroy" {
							leaveRoomFinished()
						}
						
						/// Events
						if janus == "hangup" {
							processHangup(data: data)
						}
						if janus == "event" {
							processEvents(data: data)
							processJoinedPublisher(data: data)
						}
					}
				}
			}
		} catch {
			print(error.localizedDescription)
		}
	}
	
	private func processJoinedRoom(data: Data) {
		do {
			let joined = try data.decoded() as JanusJoinedRoom
			roomManager.currentRoom = joined
			delegate?.signalingClient(didJoinRoom: joined)
			configureTimer()
			/// attach 发布者
			joined.publishers.forEach{( attach(publisher: $0) )}
		} catch {
			print(error)
		}
	}
	
	private func processConfigures(data: [String: Any]) {
		guard let jsep = data["jsep"] as? [String: Any] else { return }
		guard let sdp = jsep["sdp"] as? String, let type = jsep["type"] as? String else { return }
		
		let jsepType = RTCSessionDescription.type(for: type)
		let remoteSdp = RTCSessionDescription(type: jsepType, sdp: sdp)
		delegate?.signalingClient(didReceiveRemoteSdp: remoteSdp, handleID: roomManager.handleID)
	}
	
	private func processOffer(data: [String: Any]) {
		guard let handleID = data["sender"] as? Int64,
			  let jsep = data["jsep"] as? [String: Any] else {
			return
		}
		guard let sdp = jsep["sdp"] as? String, let type = jsep["type"] as? String else { return }
		
		let jsepType = RTCSessionDescription.type(for: type)
		let remoteSdp = RTCSessionDescription(type: jsepType, sdp: sdp)
		delegate?.signalingClient(didReceiveRemoteSdp: remoteSdp, handleID: handleID)
	}
	
	private func processEvents(data: [String: Any]) {
		
	}
	
	private func leaveRoomFinished() {
		guard let currentRoom = roomManager.currentRoom else { return }
		delegate?.signalingClient(didLeaveRoom: currentRoom)
	}
	
	private func processJoinedPublisher(data: [String: Any]) {
		guard let currentRoom = roomManager.currentRoom else { return }
		/// 暂时不考虑多房间情况
		guard let plugindata = data["plugindata"] as? [String: Any],
			  let obj = plugindata["data"] as? [String: Any],
			  let publishers = obj["publishers"] as? [[String: Any]] else { return }
		/// 注意: 返回数组, **当前只取第一个**
		guard let publisher = publishers.compactMap({ JanusPublisher(dict: $0) }).first else { return }
		
		if currentRoom.publishers.contains(where:  { $0.id == publisher.id } ) {
			/// 排除重复
			return
		}
		/// 保存数据
		currentRoom.publishers.append(publisher)
		/// attach 发布者
		attach(publisher: publisher)
	}
	
	private func processSubscribeStarted(data: [String: Any]) {
		guard let handleID = data["sender"] as? Int64 else { return }
		guard let connection = roomManager.connection(for: handleID) else { return }
		NotificationCenter.default.post(name: Self.didStartSubscribingNewPublisherNotification, object: connection, userInfo: nil)
	}
	
	private func processHangup(data: [String: Any]) {
		guard let handleID = data["sender"] as? Int64 else { return }
		let hangupReason = data["reason"] as? String ?? "No Reason"
		
		if handleID == roomManager.handleID {
			/// 不处理本机 unpublish 事件
			return
		}
		/// Post Notification
		NotificationCenter.default.post(name: Self.didReciveLeaveNotification, object: ["handleID": handleID, "reason": hangupReason], userInfo: nil)
		/// Update JanusSessionManager.Connections
		let removedPublisherID = roomManager.connection(for: handleID)?.publisher.id
		roomManager.currentRoom?.publishers.removeAll(where: { $0.id == removedPublisherID })
		roomManager.connections.removeAll(where: { $0.handleID == handleID })
	}
}
