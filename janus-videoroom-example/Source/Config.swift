//
//  Config.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/21.
//

import Foundation

struct Config {
    
    static let signalingServerURL = URL(string: "ws://192.168.31.239:8188")!
    
    static let webRTCIceServers: [String] = [
        "stun:stun.l.google.com:19302",
        "stun:stun1.l.google.com:19302",
        "stun:stun2.l.google.com:19302",
        "stun:stun3.l.google.com:19302",
        "stun:stun4.l.google.com:19302"
    ]
}
