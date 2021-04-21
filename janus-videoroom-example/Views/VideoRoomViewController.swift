//
//  VideoRoomViewController.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/21.
//

import UIKit
import WebRTC
import Alertift

extension VideoRoomViewController {
    /// Show Video Page
    class func showVideo() -> VideoRoomViewController {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let view = sb.instantiateViewController(withIdentifier: "VideoRoomViewController") as! VideoRoomViewController
        return view
    }
}

class VideoRoomViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var speakerButton: UIButton!
    @IBOutlet private weak var microphonepButton: UIButton!
    
    private weak var renderer: RTCMTLVideoView?
    
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
        print("VideoViewController deinit...")
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepare()
    }
}

/// Configurations
extension VideoRoomViewController {
    
    private func prepare() {
        addObservers()
        configureRenderer()
        configureDataSource()
        configureCollectionView()
        
        titleLabel.text = currentConnection?.publisher.display
    }
    
    private func configureRenderer() {
        let renderer = RTCMTLVideoView(frame: view.bounds)
        view.insertSubview(renderer, at: 0)
        renderer.videoContentMode = .scaleAspectFill

        localRTCClient?.startCaptureLocalVideo(renderer: renderer)
        self.renderer = renderer
    }
    
    private func configureDataSource() {
        currentConnection = roomManager.localConnection
        dataSource = roomManager.connections
        dataSource.removeAll(where: { $0 == currentConnection })
    }
    
    private func configureCollectionView() {
        collectionView.register(VideoRoomCollectionViewCell.self, forCellWithReuseIdentifier: VideoRoomCollectionViewCell.identifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        view.bringSubviewToFront(collectionView)
    }
    
    private func addObservers() {        
        NotificationCenter.default.addObserver(self, selector: #selector(roomStateDidChange(_:)), name: JanusRoomManager.roomStateChangeNote, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(publisherDidLeave(_:)), name: WebSocketSignalingClient.didReciveLeaveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(publisherDidJoin(_:)), name: WebSocketSignalingClient.didStartSubscribingNewPublisherNotification, object: nil)
    }
}

/// Actions
extension VideoRoomViewController {
    
    @IBAction private func backDidTap(_ sender: Any) {
        ProgressHUD.show()
        roomManager.destroyCurrentRoom()
    }
    
    @IBAction private func switchCamera(_ sender: Any) {
        localRTCClient?.switchCamera()
    }
    
    @IBAction private func micphoneAction(_ sender: UIButton) {
        sender.isSelected.toggle()
        
        if sender.isSelected {
            localRTCClient?.muteAudio()
        } else {
            localRTCClient?.unmuteAudio()
        }
    }
    
    @IBAction private func speakerAction(_ sender: UIButton) {
        sender.isSelected.toggle()
        
        if sender.isSelected {
            localRTCClient?.speakerOff()
        } else {
            localRTCClient?.speakerOn()
        }
    }
    
    @objc private func roomStateDidChange(_ sender: Notification) {
        guard let isDestroy = sender.object as? Bool else { return }
        
        ProgressHUD.dismiss()
        if isDestroy {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc private func publisherDidLeave(_ sender: Notification) {
        guard let obj = sender.object as? [String: Any] else { return }
        guard let handleID = obj["handleID"] as? Int64, let connection = roomManager.connection(for: handleID) else { return }
        
        let reason = obj["reason"] as? String
        Alertift.alert(title: "\(connection.publisher.display) has left", message: reason).action(.cancel("dismiss")).show(on: self)
        
        guard let currentConnection = currentConnection, let renderer = renderer else { return }
        /// 先不考虑自己在视频页面离开 room
        if currentConnection.handleID == handleID {
            
            currentConnection.rtcClient?.detach(renderer: renderer, isLocal: currentConnection.isLocal)
            let last = dataSource.removeLast()
            last.rtcClient?.attach(renderer: renderer, isLocal: last.isLocal)
            collectionView.deleteItems(at: [IndexPath(item: dataSource.count, section: 0)])
            
            self.currentConnection = last
        } else {
            if let index = dataSource.firstIndex(where: { $0.handleID == handleID }) {
                let connection = dataSource.remove(at: index)
                
                let indexPath = IndexPath(item: index, section: 0)
                if let cell = collectionView.cellForItem(at: indexPath) as? VideoRoomCollectionViewCell {
                    connection.rtcClient?.detach(renderer: cell.renderView, isLocal: connection.isLocal)
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
        dataSource.append(connection)
        
        Alertift.alert(title: "\(connection.publisher.display) has joined", message: "a-\(connection.publisher.audioCodec), v-\(connection.publisher.videoCodec)").action(.cancel("dismiss")).show(on: self)
        
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
            connection.rtcClient?.detach(renderer: cell.renderView, isLocal: connection.isLocal)
            connection.rtcClient?.attach(renderer: cell.renderView, isLocal: connection.isLocal)
            if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                cell.renderView.frame = CGRect(origin: CGPoint.zero, size: layout.itemSize)
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let currentConnection = currentConnection, let renderer = renderer else { return }
        
        let selectedConnection = dataSource[indexPath.item]
        dataSource[indexPath.item] = currentConnection
        
        /// Detach Renderer From its Source
        currentConnection.rtcClient?.detach(renderer: renderer, isLocal: currentConnection.isLocal)
        /// Attach Renderer to New Source
        selectedConnection.rtcClient?.attach(renderer: renderer, isLocal: selectedConnection.isLocal)
        
        renderer.videoContentMode = .scaleAspectFill
        
        titleLabel.text = selectedConnection.publisher.display

        self.currentConnection = selectedConnection
        
        collectionView.reloadItems(at: [indexPath])
    }
}
