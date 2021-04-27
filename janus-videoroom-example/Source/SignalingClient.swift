//
//  SignalingClient.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/20.
//

import Foundation
import Starscream
import WebRTC

enum SignalingConnectionState {
	case connected([String: String])
	case disconnected(String, UInt16)
	case error(Error?)
	case cancelled
}

protocol SignalingClientConnectionDelegate: AnyObject {
    func signalingClient(didChangeState state: SignalingConnectionState)
}

protocol JanusResponseHandler: AnyObject {
	func janusHandler(received remoteSdp: RTCSessionDescription, handleID: Int64)
	func janusHandler(received candidate: RTCIceCandidate)
	func janusHandler(attachedSelf handleID: Int64)
	
	func janusHandler(joinedRoom handleID: Int64)
	func janusHandler(leftRoom handleID: Int64, reason: String?)
	
	func janusHandler(didAttach publisher: JanusPublisher, handleID: Int64)
	
	func janusHandlerDidDestroyRoom()
}

class SignalingClient {

	weak var connectionDelegate: SignalingClientConnectionDelegate?
	weak var responseHandler: JanusResponseHandler?
	
    /// 是否已经建立连接
    var isConnected: Bool = false
    
	private var timer: Foundation.Timer?
	private let socket: WebSocket
	
    private var roomManager: JanusRoomManager {
        JanusRoomManager.shared
    }
	
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
	
	/// Reconnect WebSocket After Cancelation or Error
	private func reconnect() {
		DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
			self.connect()
		}
	}
}

/// Timer & Keep alive
extension SignalingClient {

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
extension SignalingClient {
	/// 加入房间
	/// - Parameter room: 房间号
	func createRoom(room: Int) {
		let req = JanusCreateRoom(room: room)
		do {
			let msg = try encoder.encode(req)
			write(data: msg)
		} catch {
			debugPrint("Warning: Could not encode Join Request: \(error)")
		}
	}
	
	/// 离开房间
	func destroyRoom() {
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
        /// Save local handleID
		roomManager.handleID = handleID
        let room = roomManager.room
        let display = roomManager.roomDisplayName
        
        let req = JanusJoinRoom(room: room, id: id, handleID: handleID, display: display)
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
		let req = JanusSubscribeStart(room: roomManager.room, sdp: sdp, handleID: handleID, sessionID: roomManager.sessionID)
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
extension SignalingClient: WebSocketDelegate {
	
	func didReceive(event: WebSocketEvent, client: WebSocket) {
		switch event {
		case .connected(let userInfo):
            isConnected = true
			connectionDelegate?.signalingClient(didChangeState: .connected(userInfo))
		case .disconnected(let reason, let code):
            isConnected = false
			connectionDelegate?.signalingClient(didChangeState: .disconnected(reason, code))
            /// Try to reconnect
			reconnect()
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
            isConnected = false
			reconnect()
			connectionDelegate?.signalingClient(didChangeState: .cancelled)
			break
		case .error(let error):
            isConnected = false
			connectionDelegate?.signalingClient(didChangeState: .error(error))
		}
	}
}

/// Procesing
extension SignalingClient {
	
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
						responseHandler?.janusHandler(attachedSelf: id)
						sendJoinRoomRequest(id: roomManager.sessionID, handleID: id)
					} else if transaction.hasPrefix("Attach.") {
						/// Attached 成功
						guard let last = transaction.components(separatedBy: ".").last, let publisherID = Int64(last) else { return }
						guard let room = roomManager.currentRoom, let publisher = room.publisher(from: publisherID) else { return }
						///
						responseHandler?.janusHandler(didAttach: publisher, handleID: id)
						///
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
						} else if transaction == "Start" {
							processSubscribeStarted(data: data)
						} else if transaction == "Destroy" {
							destroyRoomFinished()
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
			/// Save the room just joined
			roomManager.currentRoom = joined
			/// 
			responseHandler?.janusHandler(joinedRoom: roomManager.handleID)
			/// Send keep-alive cmd
			configureTimer()
			
			if !roomManager.isBroadcast {
				/// Attach all the active publisher, if NOT broadcast screen.
				joined.publishers.forEach{( attach(publisher: $0) )}
			}
		} catch {
			print(error)
		}
	}
	
	private func processConfigures(data: [String: Any]) {
		guard let jsep = data["jsep"] as? [String: Any] else { return }
		guard let sdp = jsep["sdp"] as? String, let type = jsep["type"] as? String else { return }
		
		let jsepType = RTCSessionDescription.type(for: type)
		let remoteSdp = RTCSessionDescription(type: jsepType, sdp: sdp)
		responseHandler?.janusHandler(received: remoteSdp, handleID: roomManager.handleID)
	}
	
	private func processOffer(data: [String: Any]) {
		guard let handleID = data["sender"] as? Int64,
			  let jsep = data["jsep"] as? [String: Any] else {
			return
		}
		guard let sdp = jsep["sdp"] as? String, let type = jsep["type"] as? String else { return }
		
		let jsepType = RTCSessionDescription.type(for: type)
		let remoteSdp = RTCSessionDescription(type: jsepType, sdp: sdp)
		responseHandler?.janusHandler(received: remoteSdp, handleID: handleID)
	}
	
	private func processEvents(data: [String: Any]) {
		
	}
	
	private func destroyRoomFinished() {
		responseHandler?.janusHandlerDidDestroyRoom()
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
		/// Save Publisher to Local 保存数据
		currentRoom.publishers.append(publisher)
		/// Attach Publisher 发布者
		attach(publisher: publisher)
	}
	
	/// Subscribe Started
	private func processSubscribeStarted(data: [String: Any]) {
		guard let handleID = data["sender"] as? Int64 else { return }
		responseHandler?.janusHandler(joinedRoom: handleID)
	}
	
	private func processHangup(data: [String: Any]) {
		guard let handleID = data["sender"] as? Int64 else { return }
		let reason = data["reason"] as? String ?? "No Reason"
		
		responseHandler?.janusHandler(leftRoom: handleID, reason: reason)
	}
}
