//
//  VideoRoomViewController.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/21.
//

import UIKit
import WebRTC
import Alertift
import ReplayKit
import AVKit

extension VideoRoomViewController {
    /// Show Video Page
	class func showVideo(isBroadcasting: Bool = false) -> VideoRoomViewController {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let view = sb.instantiateViewController(withIdentifier: "VideoRoomViewController") as! VideoRoomViewController
		view.isBroadcasting = isBroadcasting
        return view
    }
}

class VideoRoomViewController: UIViewController {

	private var isBroadcasting: Bool = false
	
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var collectionView: UICollectionView!
	@IBOutlet private weak var functionStackView: UIStackView!
    @IBOutlet private weak var speakerButton: UIButton!
    @IBOutlet private weak var microphonepButton: UIButton!
    @IBOutlet private weak var videoButton: UIButton!
    @IBOutlet private weak var cameraButton: UIButton!
    @IBOutlet private weak var publishSwitch: UISwitch!
	
	private var broadcastPicker: RPSystemBroadcastPickerView?
	
    // Currently only show the selected publisher in PiP mode.
    private weak var renderer: AVSampleBufferView?
    // PiP stuff
    var isPIPSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }
    private var pipController: AVPictureInPictureController?
    private var pipPossibleObservation: NSKeyValueObservation?
    
    private var roomManager: JanusRoomManager {
        JanusRoomManager.shared
    }
    
    private var dataSource: [JanusConnection] = []
    
    private var currentConnection: JanusConnection?
    
    private var localRTCClient: WebRTCClient? {
        roomManager.localConnection?.rtcClient
    }
    
    var cameraPosition: AVCaptureDevice.Position = .front
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("VideoViewController is deinit...")
    }
    
//    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
//        .portrait
//    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepare()
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		UIApplication.shared.isIdleTimerDisabled = true
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		UIApplication.shared.isIdleTimerDisabled = false
	}
}

/// Configurations
extension VideoRoomViewController {
    
    private func prepare() {
        addObservers()
		configureBroadcastPicker()
        configureDataSource()
        configureCollectionView()
        
        publishSwitch.isOn = roomManager.shouldJoinedAsPubliherAtFirstTime
        functionStackView.arrangedSubviews.compactMap({ $0 as? UIButton }).forEach({ $0.isEnabled = roomManager.shouldJoinedAsPubliherAtFirstTime })
    }
    
	private func configureBroadcastPicker() {
		let picker = RPSystemBroadcastPickerView(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 44, height: 44)))
		picker.preferredExtension = Config.broadcastBundleIdentifier
		functionStackView.addArrangedSubview(picker)
		picker.subviews.map({ $0 as? UIButton }).forEach({
			$0?.imageView?.tintColor = .white
		})
		broadcastPicker = picker
		picker.tintColor = .white
	}

    private func configureDataSource() {
        currentConnection = roomManager.connections.filter({ $0.isLocal == false }).first
        dataSource = roomManager.connections
        dataSource.removeAll(where: { $0 == currentConnection })
        
        if currentConnection != nil {
            configureRenderer()
        }
        titleLabel.text = currentConnection?.publisher.display
    }

    private func configureRenderer() {
        let renderer = AVSampleBufferView(frame: view.bounds)
        view.insertSubview(renderer, at: 0)
        renderer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        currentConnection?.rtcClient?.attach(renderer: renderer, isLocal: false)
        
        self.renderer = renderer
    }
    
    private func configureCollectionView() {
        collectionView.register(VideoRoomCollectionViewCell.self, forCellWithReuseIdentifier: VideoRoomCollectionViewCell.identifier)
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    private func addObservers() {        
        NotificationCenter.default.addObserver(self, selector: #selector(roomStateDidChange(_:)), name: JanusRoomManager.roomStateChangeNote, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(publisherDidLeave(_:)), name: JanusRoomManager.publisherDidLeaveRoomNote, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(publisherDidJoin(_:)), name: JanusRoomManager.publisherDidJoinRoomNote, object: nil)
    }
}

/// Actions
extension VideoRoomViewController {
    
    @IBAction private func backAction(_ sender: Any) {
		Alertift.alert(title: "Leave the Room?", message: "The room will be destroyed").action(.default("Leave")) {
			ProgressHUD.show()
			self.roomManager.leaveCurrentRoom()
            
            self.renderer?.destroy()
            if #available(iOS 15.0, *) {
                self.exitPIPController()
            }
		}.action(.cancel("Not now")).show(on: self)
    }
    
    @IBAction private func switchCamera(_ sender: UIButton) {
		let image = sender.currentImage?.withTintColor(.white).withRenderingMode(.alwaysOriginal)
		ProgressHUD.showSuccess("Camera Switched", image: image)
        
        if currentConnection?.isLocal == true {
            guard let renderer = renderer else { return }
            localRTCClient?.switchCamera(renderer: renderer)
        } else {
            guard let localIndex = dataSource.lastIndex(where: { $0.isLocal }) else { return }
            guard let cell = collectionView.cellForItem(at: IndexPath(item: localIndex, section: 0)) as? VideoRoomCollectionViewCell, let renderView = cell.renderView else { return }
            let webRTCClient = dataSource[localIndex].rtcClient
            webRTCClient?.switchCamera(renderer: renderView)
        }
    }
    
    @IBAction private func micphoneAction(_ sender: UIButton) {
        sender.isSelected.toggle()
		let image = sender.image(for: sender.isSelected ? .selected : .normal)?
			.withTintColor(.white)
			.withRenderingMode(.alwaysOriginal)
		
        if sender.isSelected {
			ProgressHUD.showSuccess("Mute", image: image)
            localRTCClient?.muteAudio()
        } else {
			ProgressHUD.showSuccess("Unmute", image: image)
            localRTCClient?.unmuteAudio()
        }
    }
    
    @IBAction private func speakerAction(_ sender: UIButton) {
        sender.isSelected.toggle()
		let image = sender.image(for: sender.isSelected ? .selected : .normal)?
			.withTintColor(.white)
			.withRenderingMode(.alwaysOriginal)
		
        if sender.isSelected {
			ProgressHUD.showSuccess("Speaker Off", image: image)
            localRTCClient?.speakerOff()
        } else {
			ProgressHUD.showSuccess("Speaker On", image: image)
            localRTCClient?.speakerOn()
        }
    }
	
	@IBAction private func videoAction(_ sender: UIButton) {
		sender.isSelected.toggle()
		let image = sender.image(for: sender.isSelected ? .selected : .normal)?
			.withTintColor(.white)
			.withRenderingMode(.alwaysOriginal)
		
		if sender.isSelected {
			ProgressHUD.showSuccess("Video Off", image: image)
			localRTCClient?.hideVideo()
		} else {
			ProgressHUD.showSuccess("Video On", image: image)
			localRTCClient?.showVideo()
		}
	}
    
	@IBAction private func publishStateChanged(_ sender: UISwitch) {
        if sender.isOn {
            ProgressHUD.showSuccess("Publish")
            roomManager.publish()
            functionStackView.arrangedSubviews.compactMap({ $0 as? UIButton }).forEach({ $0.isEnabled = true })
        } else {
            ProgressHUD.showSuccess("Unpublish")
            roomManager.unpubish()
            functionStackView.arrangedSubviews.compactMap({ $0 as? UIButton }).forEach({ $0.isEnabled = false })
        }
	}
	
    @objc private func roomStateDidChange(_ sender: Notification) {
        guard let roomState = sender.object as? JanusRoomState else { return }
        
        ProgressHUD.dismiss()
        
        if roomState == .left {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc private func publisherDidLeave(_ sender: Notification) {
        guard let connection = sender.object as? JanusConnection else { return }
		let handleID = connection.handleID
        
        if connection.handleID != roomManager.handleID {
            Alertift.alert(title: "\(connection.publisher.display) has left", message: nil).action(.cancel("dismiss")).show(on: self)
        }
        
        guard let currentConnection = currentConnection, let renderer = renderer else { return }
        
        if currentConnection.handleID == handleID {
            
            currentConnection.rtcClient?.detach(renderer: renderer, isLocal: currentConnection.isLocal)
            let last = dataSource.removeLast()
            last.rtcClient?.attach(renderer: renderer, isLocal: last.isLocal)
            collectionView.deleteItems(at: [IndexPath(item: dataSource.count, section: 0)])
            
            currentConnection.rtcClient?.destory()
            
            self.currentConnection = last
        } else {
            if let index = dataSource.firstIndex(where: { $0.handleID == handleID }) {
                let connection = dataSource.remove(at: index)
                
                let indexPath = IndexPath(item: index, section: 0)
                if let cell = collectionView.cellForItem(at: indexPath) as? VideoRoomCollectionViewCell, let renderView = cell.renderView {
                    connection.rtcClient?.detach(renderer: renderView, isLocal: connection.isLocal)
                }
                
                connection.rtcClient?.destory()
                collectionView.deleteItems(at: [indexPath])
            }
        }
    }
    
    @objc private func publisherDidJoin(_ sender: Notification) {
        guard let connection = sender.object as? JanusConnection else { return }
        if dataSource.contains(where: { $0.handleID == connection.handleID }) {
            return
        }
        
        if currentConnection == nil {
            configureDataSource()
            
            if #available(iOS 15.0, *) {
                prepareToPIPController()
            }
        } else {
            dataSource.append(connection)
        }
        
        if connection.handleID != roomManager.handleID {
            Alertift.alert(title: "\(connection.publisher.display) has joined", message: "a-\(connection.publisher.audioCodec ?? "null"), v-\(connection.publisher.videoCodec ?? "null")").action(.cancel("dismiss")).show(on: self)
        }
        
        collectionView.reloadData()
    }
}

extension VideoRoomViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoRoomCollectionViewCell.identifier, for: indexPath)
        let connection = dataSource[indexPath.item]
        if let cell = cell as? VideoRoomCollectionViewCell {
            /// Attach Renderer to New Source
            cell.update(with: connection)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let currentConnection = currentConnection, let renderer = renderer else { return }
        
        let selectedConnection = dataSource[indexPath.item]
        
        // Camera rendering is NOT support in PiP mode
        // (I have not request the `Accessing the Camera While Multitasking` permission from Apple successfully)
        if selectedConnection.isLocal {
            return
        }
        
        dataSource[indexPath.item] = currentConnection
        
        /// Detach Renderer From its Source
        currentConnection.rtcClient?.detach(renderer: renderer, isLocal: currentConnection.isLocal)
        /// Attach Renderer to New Source
        selectedConnection.rtcClient?.attach(renderer: renderer, isLocal: selectedConnection.isLocal)
        
        titleLabel.text = selectedConnection.publisher.display

        self.currentConnection = selectedConnection
        
        collectionView.reloadItems(at: [indexPath])
    }
}

@available(iOS 15.0, *)
extension VideoRoomViewController {
    
    private func prepareToPIPController() {
        guard isPIPSupported else {
            return
        }
        
        guard let sampleBufferDisplayLayer = renderer?.layer as? AVSampleBufferDisplayLayer else {
            return
        }
        
        let contentSource = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: sampleBufferDisplayLayer, playbackDelegate: self)
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        pipPossibleObservation = pipController?.observe(
            \AVPictureInPictureController.isPictureInPicturePossible,
             options: [.initial, .new],
             changeHandler: { [weak self] _, changed in
                 DispatchQueue.main.async {
                     if changed.newValue == true {
                         self?.start()
                     }
                 }
             })
    }
    
    private func exitPIPController() {
        pipPossibleObservation?.invalidate()
        pipController = nil
    }
    
    func start() {
        if pipController == nil {
            prepareToPIPController()
        }
        
        guard let pipController = pipController,
                pipController.isPictureInPicturePossible,
                pipController.isPictureInPictureActive == false else {
            return
        }
        
        pipController.startPictureInPicture()
    }
    
    func stop() {
        pipController?.stopPictureInPicture()
    }
}

@available(iOS 15.0, *)
extension VideoRoomViewController: AVPictureInPictureControllerDelegate {
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        stop()
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
//        exitPIPController()
    }
}

@available(iOS 15.0, *)
extension VideoRoomViewController: AVPictureInPictureSampleBufferPlaybackDelegate {
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {}
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
    
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }
    
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        false
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
