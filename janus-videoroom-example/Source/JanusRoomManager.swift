//
//  JanusRoomManager.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/20.
//

import UIKit
import WebRTC

enum JanusRoomState {
    case `default`, joined, publishingSubscribing, subscribingOnly, left
    
    var isStreaming: Bool {
        self == .publishingSubscribing || self == .subscribingOnly
    }
}

/// Public Notifications
extension JanusRoomManager {
    /// Signaling State Change Notification, Object: `SignalingConnectionState`
    static let signalingStateChangeNote = Notification.Name("kSignalingStateChangeNote")
    /// Room State Update Events, 房间状态更新事件回调, Object: `JanusRoomState`
    static let roomStateChangeNote = Notification.Name("kRoomStateChangeNote")
    /// WebRTC Client State Change Events, Object: `(WebRTCClient, RTCIceConnectionState)`
    static let rtcClientStateChangeNote = Notification.Name("kRTCClientStateChangeNote")
	/// Object: [String: Any] , contains keys: `handleID` & `reason`
	static let publisherDidLeaveRoomNote = Notification.Name("kPublisherDidLeaveRoomNote")
	/// New publisher Joined the room, Object: `JanusConnection`
	static let publisherDidJoinRoomNote = Notification.Name("kPublisherDidJoinRoomNote")
    /// Error Response, Object: error desc `String`
    static let didReceiveErrorResponse = Notification.Name("kDidReceiveErrorResponse")
    /// External SampleCapturer did create, Object: `RTCExternalSampleCapturer` optional
    static let externalSampleCapturerDidCreateNote = Notification.Name("kExternalSampleCapturerDidCreateNote")
}

/// 当前仅同时处理一个房间, 切换房间请先调用 `JanusRoomManager.reset()`,  并更改房间号
/// Currently Support Single Room at the same time
final class JanusRoomManager {
	
	static let shared = JanusRoomManager()
    
	/// Current Room Number, default: 1234 房间号, 默认1234
	var room: Int = 1234
	/// Local Publisher Display Name 作为发布者在房间中显示的名称
	var roomDisplayName: String = UIDevice.current.name
	/// Session ID
    private(set) var sessionID: Int64 = 0
	/// Handle ID
	private(set) var handleID: Int64 = 0
	/// 当前加入的房间信息, from janus
	var currentRoom: JanusJoinedRoom?
	/// 所有的 Connection, 包含 local connection
	var connections: [JanusConnection] = []
    /// WebSocket Signaling Client
    /// Handle Send & Process Jannus Messages
    var signalingClient: SignalingClient
    
    var roomState: JanusRoomState = .default
    
	/// 是否为屏幕分享
    var isBroadcasting: Bool = false {
        didSet {
            if isBroadcasting {
                roomDisplayName = UIDevice.current.name + "-Screen"
            }
        }
    }
    
    /// 在初次进入房间时, 是否以发布者身份来进入
    var shouldJoinedAsPubliherAtFirstTime: Bool = true
    /// 是否已经以发布者身份进入过房间
    private(set) var isJoinedAsPublisher: Bool = false
    
	private init() {
        signalingClient = SignalingClient(url: Config.signalingServerURL)
    }
    
    /// 重置, 当离开房间后需要调用此方法
    /// Reset, Call this func after leaving a room
    func reset() {
        connections.forEach({ $0.rtcClient?.destory() })
        connections.removeAll()
        sessionID = 0
        handleID = 0
        currentRoom = nil
        
        roomState = .default
        isJoinedAsPublisher = false
    }
}

/// Connection Handling
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
}

/// Signaling Control
extension JanusRoomManager {
    /// connect to the singaling server
    func connect() {
        if signalingClient.isConnected {
            return
        }
        signalingClient.connectionDelegate = self
		signalingClient.responseHandler = self
        signalingClient.connect()
    }
    
    /// disconnect
    func disconnect() {
        signalingClient.disconnect()
    }
    
    /// Join a room with specific room number
    func joinRoom(room: Int) {
        self.room = room
        signalingClient.createRoomSession(room: room)
    }
    
    /// leave & destroy current room
    func leaveCurrentRoom() {
        signalingClient.leaveRoom()
    }
    
    func publish() {
        /// Create Local Connection
        createLocalJanusConnection()
        
        if !isJoinedAsPublisher {
            /// Join Room As Publisher
            signalingClient.joinRoomAsPublisher(id: sessionID, handleID: handleID)
        } else {
            /// Publish Local Media
            publishLocalMediaStream()
        }
    }
    
    func unpubish() {
        signalingClient.unpublish()
    }
}
 
/// WebSocketSignalingClientDelegate
extension JanusRoomManager: SignalingClientConnectionDelegate {
    
    func signalingClient(didChangeState state: SignalingConnectionState) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.signalingStateChangeNote, object: state)
        }
    }
}

/// JanusResponseHandler
extension JanusRoomManager: JanusResponseHandler {
	
    func janusHandler(receivedError reason: String) {
        print("Received Janus Response Error: \(reason)")
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didReceiveErrorResponse, object: reason)
        }
    }
    
    func janusHandler(didCreateSession sessionID: Int64) {
        self.sessionID = sessionID
    }
    
	func janusHandler(received remoteSdp: RTCSessionDescription, handleID: Int64) {
		print("Received remote sdp")
        let connection_ = connection(for: handleID)
        let rtcClient = connection_?.rtcClient
		rtcClient?.set(remoteSdp: remoteSdp) { [weak self] (error) in
			guard let self = self else { return }
			
			if handleID == self.handleID {
				/// Local
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.publisherDidJoinRoomNote, object: connection_, userInfo: nil)
                    self.isJoinedAsPublisher = true
                }
			} else {
				/// Others
				rtcClient?.answer { [weak self] (sdp) in
					guard let self = self else { return }
					self.signalingClient.sendAnswer(sdp: sdp.sdp, handleID: handleID)
				}
			}
		}
	}
	
	func janusHandler(received candidate: RTCIceCandidate) {
		print("Received remote candidate")
	}
	
	func janusHandler(fetched handleID: Int64) {
        /// Save local handleID
        self.handleID = handleID
        
        if shouldJoinedAsPubliherAtFirstTime {
            /// Join Room As Publisher
            signalingClient.joinRoomAsPublisher(id: sessionID, handleID: handleID)
            /// Local Connection
            createLocalJanusConnection()
        } else {
            /// Get Participants then Subscribe
            signalingClient.listparticipants()
        }
	}
	
	func janusHandler(joinedRoom handleID: Int64) {
		if handleID == self.handleID {
			/// Joined as publisher
            if roomState == .default {
                if shouldJoinedAsPubliherAtFirstTime {
                    roomState = .publishingSubscribing
                    publishLocalMediaStream()
                } else {
                    roomState = .subscribingOnly
                }
                /// Make a callback to Observers.
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.roomStateChangeNote, object: self.roomState)
                }
            } else if roomState == .subscribingOnly {
                roomState = .publishingSubscribing
                publishLocalMediaStream()
            }
		} else {
			/// Publisher has attached
			guard let connection = connection(for: handleID) else { return }
			NotificationCenter.default.post(name: Self.publisherDidJoinRoomNote, object: connection, userInfo: nil)
		}
	}
	
	func janusHandler(leftRoom handleID: Int64, reason: String?) {
		if handleID == self.handleID {
            /// Post Notification
            NotificationCenter.default.post(name: Self.publisherDidLeaveRoomNote, object: localConnection, userInfo: nil)
        } else {
            let targetConnection = connection(for: handleID)
            /// Post Notification
            NotificationCenter.default.post(name: Self.publisherDidLeaveRoomNote, object: targetConnection, userInfo: nil)
            /// Update Publishers
            let removedPublisherID = targetConnection?.publisher.id
            currentRoom?.publishers.removeAll(where: { $0.id == removedPublisherID })
        }
        /// Update Connections
        connections.removeAll(where: { $0.handleID == handleID })
	}
	
	func janusHandler(didAttach publisher: JanusPublisher, handleID: Int64) {
		let rtcClient = WebRTCClient(iceServers: Config.webRTCIceServers, id: "\(handleID)")
		rtcClient.delegate = self
		let connection = JanusConnection(handleID: handleID, publisher: publisher)
		connection.rtcClient = rtcClient
		connections.append(connection)
	}
	
	func janusHandlerDidLeaveRoom() {
        roomState = .left
        NotificationCenter.default.post(name: Self.roomStateChangeNote, object: roomState)
		/// Reset for next creating a room
		reset()
	}
    
    /// Send Offer to Remote
    private func publishLocalMediaStream() {
        localConnection?.rtcClient?.offer(completion: { [weak self] (sdp) in
            guard let self = self else { return }
            self.signalingClient.sendOffer(sdp: sdp.sdp, isConfiguration: true)
        })
    }
    
    /// Create Local Connection Object to Share Screen or Camera
    private func createLocalJanusConnection() {
        if localConnection != nil {
            return
        }
        let rtcClient = WebRTCClient(iceServers: Config.webRTCIceServers, id: "\(handleID)", delegate: self)
        let localPublisher = JanusPublisher(id: sessionID, display: roomDisplayName)
        let localConnection = JanusConnection(handleID: handleID, publisher: localPublisher)
        localConnection.rtcClient = rtcClient
        connections.insert(localConnection, at: 0)
    }
}

extension JanusRoomManager: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        print("Discovered local candidate")
        guard let handleID = connection(for: client)?.handleID else { return }
        signalingClient.send(candidate: candidate, handleID: handleID)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        print("Connection state did change: \(state.description)")
        NotificationCenter.default.post(name: Self.rtcClientStateChangeNote, object: (client, state))
    }
    
    func webRTCClient(_ client: WebRTCClient, didAdd stream: RTCMediaStream) {
        
    }
    
    func webRTCClient(_ client: WebRTCClient, didCreate externalSampleCapturer: ScreenSampleCapturer?) {
        NotificationCenter.default.post(name: Self.externalSampleCapturerDidCreateNote, object: externalSampleCapturer)
    }
}
