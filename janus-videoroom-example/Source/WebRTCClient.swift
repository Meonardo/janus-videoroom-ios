//
//  WebRTCClient.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/20.
//

import UIKit
import WebRTC

protocol WebRTCClientDelegate: AnyObject {
	func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
	func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
	func webRTCClient(_ client: WebRTCClient, didAdd stream: RTCMediaStream)
	func webRTCClient(_ client: WebRTCClient, didCreate externalSampleCapturer: ScreenSampleCapturer?)
}

extension WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didCreate externalSampleCapturer: ScreenSampleCapturer?) {}
}

final class WebRTCClient: NSObject {
	
	// The `RTCPeerConnectionFactory` is in charge of creating new RTCPeerConnection instances.
	// A new RTCPeerConnection should be created every new call, but the factory is shared.
	private static let factory: RTCPeerConnectionFactory = {
		RTCInitializeSSL()
		let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
		let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
		return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
	}()
	
	weak var delegate: WebRTCClientDelegate?
	private let peerConnection: RTCPeerConnection
	private let rtcAudioSession =  RTCAudioSession.sharedInstance()
	private let audioQueue = DispatchQueue(label: "audio")
	private let mediaConstrains = [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
								   kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue]
	private var videoCapturer: RTCVideoCapturer?
	
	private var localVideoTrack: RTCVideoTrack?
	private var remoteVideoTrack: RTCVideoTrack?

	let maxResolution: Int32 = 720
    let maxFps = 20
    
	var identifier: String
	var cameraPosition: AVCaptureDevice.Position = .front
	
	@available(*, unavailable)
	override init() {
		fatalError("WebRTCClient:init is unavailable")
	}
	
	deinit {
		print("WebRTCClient is deinit...")
	}
	
    required init(iceServers: [String], id: String, delegate: WebRTCClientDelegate? = nil) {
		let config = RTCConfiguration()
		config.iceServers = [RTCIceServer(urlStrings: iceServers)]
		
		// Unified plan is more superior than planB
		config.sdpSemantics = .unifiedPlan
		
		// gatherContinually will let WebRTC to listen to any network changes and send any new candidates to the other client
		config.continualGatheringPolicy = .gatherContinually
		
		// Define media constraints. DtlsSrtpKeyAgreement is required to be true to be able to connect with web browsers.
		let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
											  optionalConstraints: ["DtlsSrtpKeyAgreement":kRTCMediaConstraintsValueTrue])
		peerConnection = WebRTCClient.factory.peerConnection(with: config, constraints: constraints, delegate: nil)!
		
		identifier = id
        self.delegate = delegate
        
		super.init()
		
		createMediaSenders()
		configureAudioSession()
		peerConnection.delegate = self
	}
	
	func destory() {
		peerConnection.delegate = nil
		peerConnection.close()
	}
}

// MARK: - Configurations
extension WebRTCClient {
	
    private func createMediaSenders() {
		#if !TARGET_IS_EXTENSION
		// Audio
		let audioTrack = createAudioTrack()
		peerConnection.add(audioTrack, streamIds: [identifier])
		#endif
        // Video
        let videoTrack = createVideoTrack()
        localVideoTrack = videoTrack
        peerConnection.add(videoTrack, streamIds: [identifier])
    }
    
	private func configureAudioSession() {
		rtcAudioSession.lockForConfiguration()
		do {
			try rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
			try rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
		} catch let error {
			debugPrint("Error changeing AVAudioSession category: \(error)")
		}
		rtcAudioSession.unlockForConfiguration()
	}
	
	private func createAudioTrack() -> RTCAudioTrack {
		let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
		let audioSource = WebRTCClient.factory.audioSource(with: audioConstrains)
		let audioTrack = WebRTCClient.factory.audioTrack(with: audioSource, trackId: "audio0")
		return audioTrack
	}
	
	private func createVideoTrack() -> RTCVideoTrack {
		let videoSource = WebRTCClient.factory.videoSource()
    
        #if TARGET_IS_EXTENSION
        let videoCapturer = ScreenSampleCapturer(delegate: videoSource)
        self.videoCapturer = videoCapturer
        delegate?.webRTCClient(self, didCreate: videoCapturer)
        #else
        let videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        videoCapturer.rotationDelegate = self
        self.videoCapturer = videoCapturer
        #endif
		
		let videoTrack = WebRTCClient.factory.videoTrack(with: videoSource, trackId: "video0")
		return videoTrack
	}
}

// MARK: - Signaling
extension WebRTCClient {
	
	func offer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
		let constrains = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains,
											 optionalConstraints: nil)
		peerConnection.offer(for: constrains) { [weak self] (sdp, error) in
			guard let self = self else { return }
			guard let sdp = sdp else { return }
			
			self.peerConnection.setLocalDescription(sdp, completionHandler: { (error) in
				completion(sdp)
			})
		}
	}
	
	func answer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void)  {
		let constrains = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains,
											 optionalConstraints: nil)
		peerConnection.answer(for: constrains) { [weak self] (sdp, error) in
			guard let self = self else { return }
			guard let sdp = sdp else { return }
			
			self.peerConnection.setLocalDescription(sdp, completionHandler: { (error) in
				completion(sdp)
			})
		}
	}
	
	func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> ()) {
		peerConnection.setRemoteDescription(remoteSdp, completionHandler: completion)
	}
	
	func set(remoteCandidate: RTCIceCandidate) {
        peerConnection.add(remoteCandidate) { error in
            debugPrint("peerConnection add remoteCandidate failed, Error: \(error?.localizedDescription ?? "!no reason")")
        }
	}
}

// MARK: - Renderer Handling
extension WebRTCClient {
	
	func detach(renderer: RTCVideoRenderer, isLocal: Bool) {
		if isLocal {
			localVideoTrack?.remove(renderer)
		} else {
			remoteVideoTrack?.remove(renderer)
		}
	}
	
    @available(iOSApplicationExtension, unavailable)
	func attach(renderer: RTCVideoRenderer, isLocal: Bool) {
        /// **Notice**: Use `RTCMTLVideoView` as renderer only.
        guard let view = renderer as? RTCMTLVideoView else { return }
        if isLocal {
            adjustTransformIfNecessary(for: view)
            startCaptureLocalVideo(renderer: renderer)
        } else {
            view.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            renderRemoteVideo(to: renderer)
        }
	}
	
    @available(iOSApplicationExtension, unavailable)
	func startCaptureLocalVideo(renderer: RTCVideoRenderer) {
		guard let capturer = videoCapturer as? RTCCameraVideoCapturer else { return }
		
		if let camera = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == cameraPosition }) {
			let supportFormats = RTCCameraVideoCapturer.supportedFormats(for: camera)
			guard let selectedFormat = (supportFormats.filter({ (f) -> Bool in
				let width1 = CMVideoFormatDescriptionGetDimensions(f.formatDescription).width
				return width1 <= maxResolution
			}).last) else { return }
			
			guard let fpsRange = (selectedFormat.videoSupportedFrameRateRanges.sorted { return $0.maxFrameRate < $1.maxFrameRate }.last) else { return }
            let fps = min(Int(fpsRange.maxFrameRate), maxFps)
			capturer.startCapture(with: camera,
								  format: selectedFormat,
                                  fps: fps) { [weak self] error in
                DispatchQueue.main.async {
                    if let renderer = renderer as? RTCMTLVideoView {
                        self?.adjustTransformIfNecessary(for: renderer)
                    }
                }
            }
			
			localVideoTrack?.add(renderer)
		}
	}
    
    @available(iOSApplicationExtension, unavailable)
    func switchCamera(renderer: RTCVideoRenderer) {
		guard let capturer = videoCapturer as? RTCCameraVideoCapturer else { return }
		
		cameraPosition = cameraPosition == .front ? .back : .front
		
		if let camera = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == cameraPosition }) {
			let supportFormats = RTCCameraVideoCapturer.supportedFormats(for: camera)
			guard let selectedFormat = (supportFormats.filter({ (f) -> Bool in
				let width1 = CMVideoFormatDescriptionGetDimensions(f.formatDescription).width
				return width1 <= maxResolution
			}).last) else { return }
			
            guard let fpsRange = (selectedFormat.videoSupportedFrameRateRanges.sorted { return $0.maxFrameRate < $1.maxFrameRate }.last) else { return }
            let fps = min(Int(fpsRange.maxFrameRate), maxFps)
			capturer.startCapture(with: camera,
								  format: selectedFormat,
                                  fps: fps) { [weak self] error in
                DispatchQueue.main.async {
                    if let renderer = renderer as? RTCMTLVideoView {
                        self?.adjustTransformIfNecessary(for: renderer)
                    }
                }
            }
		}
	}
	
	func removeLocalVideoRender(from renderer: RTCVideoRenderer) {
		localVideoTrack?.remove(renderer)
	}
	
	func renderRemoteVideo(to renderer: RTCVideoRenderer) {
		remoteVideoTrack?.add(renderer)
	}
	
	func removeRemoteVideoRender(from renderer: RTCVideoRenderer) {
		remoteVideoTrack?.remove(renderer)
	}
    
    private func adjustTransformIfNecessary(for renderer: RTCMTLVideoView) {
        if cameraPosition == .front {
            renderer.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        } else {
            renderer.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        }
    }
}

extension WebRTCClient: RTCPeerConnectionDelegate {
	
	func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
		debugPrint("peerConnection new signaling state: \(stateChanged)")
	}
	
	func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
		debugPrint("peerConnection did add stream")
		remoteVideoTrack = stream.videoTracks.first
		delegate?.webRTCClient(self, didAdd: stream)
	}
	
	func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
		debugPrint("peerConnection did remove stream")
	}
	
	func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
		debugPrint("peerConnection should negotiate")
	}
	
	func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
		debugPrint("peerConnection new connection state: \(newState)")
		delegate?.webRTCClient(self, didChangeConnectionState: newState)
	}
	
	func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
		debugPrint("peerConnection new gathering state: \(newState)")
	}
	
	func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
		delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
	}
	
	func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
		debugPrint("peerConnection did remove candidate(s)")
	}
	
	func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
		debugPrint("peerConnection did open data channel")
	}
}

@available(iOSApplicationExtension, unavailable)
extension WebRTCClient: RTCVideoCapturerOrientationDelegate {
    
    func rotationForCameraVideoCapturer() -> RTCVideoRotation {
        RTCVideoRotation._90
    }
}

extension WebRTCClient {
	
	private func setTrackEnabled<T: RTCMediaStreamTrack>(_ type: T.Type, isEnabled: Bool) {
		peerConnection.transceivers
			.compactMap { return $0.sender.track as? T }
			.forEach { $0.isEnabled = isEnabled }
	}
}

// MARK: - Video Control
extension WebRTCClient {
	
	func hideVideo() {
		setVideoEnabled(false)
	}
	
	func showVideo() {
		setVideoEnabled(true)
	}
	
	private func setVideoEnabled(_ isEnabled: Bool) {
		setTrackEnabled(RTCVideoTrack.self, isEnabled: isEnabled)
	}
}

// MARK:- Audio Control
extension WebRTCClient {
	
	func muteAudio() {
		setAudioEnabled(false)
	}
	
	func unmuteAudio() {
		setAudioEnabled(true)
	}
	
	// Fallback to the default playing device: headphones/bluetooth/ear speaker
	func speakerOff() {
		audioQueue.async { [weak self] in
			guard let self = self else { return }
			
			self.rtcAudioSession.lockForConfiguration()
			do {
				try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
				try self.rtcAudioSession.overrideOutputAudioPort(.none)
			} catch let error {
				debugPrint("Error setting AVAudioSession category: \(error)")
			}
			self.rtcAudioSession.unlockForConfiguration()
		}
	}
	
	// Force speaker
	func speakerOn() {
		audioQueue.async { [weak self] in
			guard let self = self else { return }
			
			self.rtcAudioSession.lockForConfiguration()
			do {
				try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
				try self.rtcAudioSession.overrideOutputAudioPort(.speaker)
				try self.rtcAudioSession.setActive(true)
			} catch let error {
				debugPrint("Couldn't force audio to speaker: \(error)")
			}
			self.rtcAudioSession.unlockForConfiguration()
		}
	}
	
	private func setAudioEnabled(_ isEnabled: Bool) {
		setTrackEnabled(RTCAudioTrack.self, isEnabled: isEnabled)
	}
}

