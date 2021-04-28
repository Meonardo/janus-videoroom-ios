//
//  SampleHandler.swift
//  Broadcast
//
//  Created by Meonardo on 2021/4/22.
//

import ReplayKit
import WebRTC
import WebKit

class SampleHandler: RPBroadcastSampleHandler {

    private let logging = RTCCallbackLogger()
    private var roomManger = JanusRoomManager.shared
    private let userDefault = UserDefaults(suiteName: Config.sharedGroupName)
    
    private var capturer: ScreenSampleCapturer?
    
    private let containerAppURL = URL(string: "https://2dbcccb478cc.ngrok.io")!
    
    private var webView: WKWebView?
    
    private var appContext: NSExtensionContext?
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
		roomManger.isBroadcast = true
        addNotificationObserver()
        roomManger.connect()
        
        openContainerApp()
    }
    
    override func broadcastAnnotated(withApplicationInfo applicationInfo: [AnyHashable : Any]) {
        super.broadcastAnnotated(withApplicationInfo: applicationInfo)
        print(applicationInfo)
    }
    
    override func beginRequest(with context: NSExtensionContext) {
        super.beginRequest(with: context)
        self.appContext = context
    }
    
    override func broadcastPaused() {
        
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
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

extension SampleHandler: WKNavigationDelegate {
    
    private func addNotificationObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(signalingStateChange(_:)), name: JanusRoomManager.signalingStateChangeNote, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(roomStateChange(_:)), name: JanusRoomManager.roomStateChangeNote, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sampleBufferCapturerDidCreate(_:)), name: JanusRoomManager.externalSampleCapturerDidCreateNote, object: nil)
    }
    
    @objc private func signalingStateChange(_ sender: Notification) {
        guard let state = sender.object as? SignalingConnectionState else { return }
        
        if case .connected = state {
            guard let lastJoinedRoom = userDefault?.string(forKey: Config.lastJoinedRoomKey), let room = Int(lastJoinedRoom) else { return }
            roomManger.createRoom(room: room)
        }
    }
    
    @objc private func roomStateChange(_ sender: Notification) {
        guard let isDestroy = sender.object as? Bool else { return }
        print(isDestroy)
    }
    
    @objc private func sampleBufferCapturerDidCreate(_ sender: Notification) {
        guard let capturer = sender.object as? ScreenSampleCapturer else { return }
        self.capturer = capturer
    }
    
    private func openContainerApp() {
        DispatchQueue.main.async {
            guard let application = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication else { return }
            let selector = NSSelectorFromString("openURL:")
            application.perform(selector, with: self.containerAppURL)
            
            let webView = WKWebView(frame: CGRect.zero)
            webView.load(URLRequest(url: self.containerAppURL))
            webView.reload()
            webView.navigationDelegate = self
            self.webView = webView
        }

    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print(error)
    }
}
