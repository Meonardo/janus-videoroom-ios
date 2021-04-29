//
//  WormholeMessages.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/29.
//

import Foundation
import Wormhole

enum BroadcastCapturingState: Int, Codable {
    case `default`, paused, running, finished
}

struct WormholeMessages {
    /// Broadcast Paths
    static let captureStateDidChange = "CaptureStateDidChange"
    static let stopCapturing = "StopCapturing"
    
    /// Container
    static let container = "kWormholeContainer"
}

class WormholeResponseMessage: Codable {

    var success: Bool = true
    var data: CodableBox?
    
    var error: String? = nil
    var code: Int = 0
    
    init(data: CodableBox?) {
        self.data = data
    }
    
    class var empty: WormholeResponseMessage {
        let data = WormholeResponseMessage(data: nil)
        data.success = false
        data.code = -1
        data.error = "Empty Data"
        return data
    }
}

typealias WormholeResponse = (WormholeResponseMessage) -> Void

class WormholeSessionManager {
    
    private var id: String
    private var wormhole: Wormhole
    private var responseHandlers: [String: Codable?] = [:]
    
    init(indentifier: String, pathsToRegister: [String]) {
        id = indentifier
        wormhole = Wormhole(appGroup: Config.sharedGroupName, container: WormholeMessages.container, transitingType: .file)
        
//        registerListener(paths: pathsToRegister)
    }
    
    private func registerListener(paths: [String]) {
        paths.forEach { (path) in
            wormhole.listenForMessage(with: path) { [weak self] box in
                self?.responseHandlers[path] = box
            }
        }
    }
    
    //MARK: - Server
    
    func post<T: Codable>(message: T, to path: String, handle: (Codable?, (T?) -> Void) -> Void ) {
        let requestData = responseHandlers[path] as? Codable
        
        let handleResult: (T?) -> Void = { [weak self] (data) in
            self?.wormhole.passMessage(data, with: path)
        }
        handle(requestData, handleResult)
    }
    
    //MARK: - Client
    
    func send<T: Codable>(message: T, to path: String, response: WormholeResponse?) {
//        wormhole.passMessage(message, with: path)
        wormhole.listenForMessage(with: path) { box in
            guard let box = box?.open(as: WormholeResponseMessage.self) else {
                response?(WormholeResponseMessage.empty)
                return
            }
            response?(box)
        }
    }
}
