//
//  Config.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/21.
//

import Foundation

enum BroadcastState: Int, Codable {
    case `default`, running, paused, resumed, finished
}

struct Config {
    /// Janus Official Demo Signaling Server Address: wss://janus.conf.meetecho.com/ws
    static let signalingServerURL = URL(string: "ws://192.168.31.240:8188")!
    
    static let webRTCIceServers: [String] = [
        "stun:stun.l.google.com:19302",
        "stun:stun1.l.google.com:19302",
        "stun:stun2.l.google.com:19302",
        "stun:stun3.l.google.com:19302",
        "stun:stun4.l.google.com:19302"
    ]
    
    static let sharedGroupName = "group.amdox.janus.videoroom"
    static let lastJoinedRoomKey = "kLastJoinedRoomKey"
	static let broadcastBundleIdentifier = "com.meonardo.janus.videoroom.Broadcast"
    static let mainAppBundleIdentifier = "com.meonardo.janus.videoroom"
    
    
    static let wormholeContainer = "kWormholeContainer"
}
