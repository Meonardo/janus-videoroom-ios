//
//  SampleHandler.swift
//  Broadcast
//
//  Created by Meonardo on 2021/4/22.
//

import ReplayKit
import WebRTC
import Wormhole
import CocoaAsyncSocket

class SampleHandler: RPBroadcastSampleHandler {

    private var roomManger = JanusRoomManager.shared
    private let userDefault = UserDefaults(suiteName: Config.sharedGroupName)
    
    private var capturer: ScreenSampleCapturer?
    private var socket: GCDAsyncSocket?
    
    private var seq: UInt32 = 0
    
    private lazy var sessionManager: WormholeSessionManager = {
        WormholeSessionManager(indentifier: Config.broadcastBundleIdentifier, pathsToRegister: [WormholeMessages.captureStateDidChange, WormholeMessages.stopCapturing])
    }()
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        let queue = DispatchQueue(label: "com.gcd.socket.send.q")
        socket = GCDAsyncSocket(delegate: self, delegateQueue: queue, socketQueue: queue)
        do {
            try socket?.connect(toHost: "127.0.0.1", onPort: Config.SOCKET_PORT)
        } catch {
            print("Connect socket error: \(error.localizedDescription)")
        }
        
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
//            capturer?.didCaptureVideo(sampleBuffer: sampleBuffer)
            if socket?.isConnected == true {
                sendSampleBuff2Host(sampleBuffer: sampleBuffer, type: sampleBufferType)
            }
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
    
    private func sendSampleBuff2Host(sampleBuffer: CMSampleBuffer, type: RPSampleBufferType) {
        if sampleBuffer.numSamples != 1 || !sampleBuffer.isValid || !CMSampleBufferDataIsReady(sampleBuffer) {
            return
        }
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
    
        seq += 1
        
        let tuple = getData(from: pixelBuffer)
        let data = tuple.0
        let yLength = tuple.1
        let cbcrLength = tuple.2
        
//        let string = "Send test message"
//        let strData = string.data(using: .utf8)!
        let buff = constructorPacket(body: data, seq: seq, yLength: UInt32(yLength), cbcrLength: UInt32(cbcrLength))
        send(data: buff)
    }
    
    private func sendSampleBuff2Host(data: Data, seq: UInt32) {
        let bytesCount = data.count
        
        data.withUnsafeBytes{ (bufferRawBufferPointer) in
            let bufferPointer: UnsafePointer<UInt8> = bufferRawBufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let mutRawPointer = UnsafeMutableRawPointer(mutating: bufferPointer)
            let uploadChunkSize = chunkSize
            let totalSize = bytesCount
            var offset = 0

            while offset < totalSize {
                let chunkSize = offset + uploadChunkSize > totalSize ? totalSize - offset : uploadChunkSize
                let chunk = Data(bytesNoCopy: mutRawPointer+offset, count: chunkSize, deallocator: Data.Deallocator.none)
                
                send(data: chunk)
                offset += chunkSize
            }
            
            let end = PixelDataST.endData(bodyLength: UInt32(bytesCount), seq: seq, yLength: 0, cbcrLength: 0)
            send(data: end.representData)
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

extension SampleHandler: GCDAsyncSocketDelegate {
    
    func send(data: Data) {
        socket?.write(data, withTimeout: 0, tag: 0)
    }
        
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("Socket connected")
        sock.readData(withTimeout: -1, tag: 0)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("Socket error: \(err?.localizedDescription ?? "no reason")")
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        
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
