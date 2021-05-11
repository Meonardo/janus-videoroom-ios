//
//  SampleHandler.swift
//  Broadcast
//
//  Created by Meonardo on 2021/4/22.
//

import ReplayKit
import WebRTC
import Wormhole

class SampleHandler: RPBroadcastSampleHandler {

    private var roomManger = JanusRoomManager.shared
    private let userDefault = UserDefaults(suiteName: Config.sharedGroupName)
    
    private var capturer: ScreenSampleCapturer?
    
    private lazy var sessionManager: WormholeSessionManager = {
        WormholeSessionManager(indentifier: Config.broadcastBundleIdentifier, pathsToRegister: [WormholeMessages.captureStateDidChange, WormholeMessages.stopCapturing])
    }()
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        capturingStateDidChange(.running)
        
		roomManger.isBroadcasting = true
        addNotificationObserver()
        roomManger.connect()
        
        openContainerApp()
    }
    
    override func broadcastAnnotated(withApplicationInfo applicationInfo: [AnyHashable : Any]) {
        super.broadcastAnnotated(withApplicationInfo: applicationInfo)
        print(applicationInfo)
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
        capturingStateDidChange(.paused)
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
        capturingStateDidChange(.running)
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        capturingStateDidChange(.finished)
        
        roomManger.reset()
        roomManger.disconnect()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            // Handle video sample buffer
            capturer?.didCaptureVideo(sampleBuffer: sampleBuffer)
            break
        case RPSampleBufferType.audioApp:
            // Handle audio sample buffer for app audio
            break
        case RPSampleBufferType.audioMic:
            // Handle audio sample buffer for mic audio
            break
        @unknown default:
            // Handle other sample buffer types
            fatalError("Unknown type of sample buffer")
        }
    }
}

extension SampleHandler {
    
    private func capturingStateDidChange(_ state: BroadcastCapturingState) {
        let response = WormholeResponseMessage(data: CodableBox(state))
        sessionManager.post(message: response, to: WormholeMessages.captureStateDidChange) { request, result in
            /// Don't need to handle request data, just return state value.
            if let value = request as? CodableBox {
                print(value.open(as: Int.self) ?? "x")
            }
            response.success = true
            response.code = 1
            result(response)
        }
    }
   
}

extension SampleHandler {
    
    private func addNotificationObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(signalingStateChange(_:)), name: JanusRoomManager.signalingStateChangeNote, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(roomStateChange(_:)), name: JanusRoomManager.roomStateChangeNote, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sampleBufferCapturerDidCreate(_:)), name: JanusRoomManager.externalSampleCapturerDidCreateNote, object: nil)
    }
    
    @objc private func signalingStateChange(_ sender: Notification) {
        guard let state = sender.object as? SignalingConnectionState else { return }
        
        if case .connected = state {
            guard let lastJoinedRoom = userDefault?.string(forKey: Config.lastJoinedRoomKey), let room = Int(lastJoinedRoom) else { return }
            roomManger.joinRoom(room: room)
        }
    }
    
    @objc private func roomStateChange(_ sender: Notification) {
        guard let roomState = sender.object as? JanusRoomState else { return }
        print(roomState)
    }
    
    @objc private func sampleBufferCapturerDidCreate(_ sender: Notification) {
        guard let capturer = sender.object as? ScreenSampleCapturer else { return }
        self.capturer = capturer
    }
    
    private func openContainerApp() {
        DispatchQueue.main.async {
//            guard let application = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication else { return }
//            let selector = NSSelectorFromString("openURL:")
//            application.perform(selector, with: self.containerAppURL)
            
//            let webView = WKWebView(frame: CGRect.zero)
//            webView.load(URLRequest(url: self.containerAppURL))
//            webView.reload()
//            webView.navigationDelegate = self
//            self.webView = webView
        }

    }
}
