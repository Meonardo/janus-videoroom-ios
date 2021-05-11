//
//  ViewController.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/20.
//

import UIKit
import ReplayKit
import Alertift

class ViewController: UIViewController {

    @IBOutlet private weak var textField: UITextField!
    @IBOutlet private weak var joinButton: UIButton!
    @IBOutlet private weak var stackView: UIStackView!
    @IBOutlet private weak var segmentControl: UISegmentedControl!
    @IBOutlet private weak var websocketStatusLabel: UILabel!
    
    private let userDefault = UserDefaults(suiteName: Config.sharedGroupName)
    
    private var roomManager: JanusRoomManager {
        JanusRoomManager.shared
    }
    
    private lazy var sessionManager: WormholeSessionManager = {
        WormholeSessionManager(indentifier: Config.mainAppBundleIdentifier, pathsToRegister: [])
    }()
    
    private lazy var broadcastPicker: RPSystemBroadcastPickerView = {
        let pick = RPSystemBroadcastPickerView(frame: CGRect(x: -100, y: -100, width: 44, height: 44))
        pick.preferredExtension = Config.broadcastBundleIdentifier
        view.addSubview(pick)
        return pick
    }()
    
    private var isSharingScreen: Bool = UIScreen.main.isCaptured
    
	override func viewDidLoad() {
		super.viewDidLoad()
        prepare()
	}
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let pos = touches.first?.location(in: view) else { return }
        if !stackView.frame.contains(pos) {
            textField.resignFirstResponder()
        }
    }
}

extension ViewController {
    
    private func prepare() {
        addNotificationObserver()
        
        textField.text = userDefault?.string(forKey: Config.lastJoinedRoomKey)
        
        roomManager.connect()
        
        if isSharingScreen {
            segmentControl.selectedSegmentIndex = 1
        }
        
        sessionManager.send(message: 1, to: WormholeMessages.captureStateDidChange) { response in
            let newState = response.data?.open(as: BroadcastCapturingState.self) ?? .default
            DispatchQueue.main.async {
                Alertift.alert(title: "New Capture State", message: "\(newState)").action(.cancel("Dismiss")).show()
            }
        }
    }
    
    private func addNotificationObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(signalingStateChange(_:)), name: JanusRoomManager.signalingStateChangeNote, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(roomStateChange(_:)), name: JanusRoomManager.roomStateChangeNote, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveErrorResponse(_:)), name: JanusRoomManager.didReceiveErrorResponse, object: nil)
    }
    
    @objc private func signalingStateChange(_ sender: Notification) {
        guard let state = sender.object as? SignalingConnectionState else { return }
        
        switch state {
        case .connected:
            websocketStatusLabel.text = "Connected"
            websocketStatusLabel.textColor = UIColor.systemGreen
        case .cancelled:
            ProgressHUD.dismiss()
            websocketStatusLabel.text = "Cancelled"
            websocketStatusLabel.textColor = UIColor.systemOrange
        case .disconnected(let reason, let code):
            ProgressHUD.dismiss()
            websocketStatusLabel.text = "Disconnected with: \(reason), code: \(code)"
            websocketStatusLabel.textColor = UIColor.systemOrange
        case .error(let err):
            ProgressHUD.dismiss()
            websocketStatusLabel.text = "Error \(err?.localizedDescription ?? "No Reason")"
            websocketStatusLabel.textColor = UIColor.systemRed
        }
    }
    
    @objc private func roomStateChange(_ sender: Notification) {
        guard let roomState = sender.object as? JanusRoomState else { return }
        
        ProgressHUD.dismiss()
        if roomState == .left {
            joinButton.isEnabled = true
        } else if roomState.isStreaming {
            let video = VideoRoomViewController.showVideo()
            video.modalPresentationStyle = .currentContext
            present(video, animated: true, completion: nil)
        }
    }
    
    @objc private func didReceiveErrorResponse(_ sender: Notification) {
        guard let reason = sender.object as? String else { return }
        
        ProgressHUD.showError(reason)
    }
}

/// Actions
extension ViewController {
    
    @IBAction private func joinAction(_ sender: UIButton) {
        guard let text = textField.text, let roomID = Int(text) else {
            ProgressHUD.showError("Room Number Must be an Integer")
            return
        }
        /// Save for next launch
        userDefault?.setValue(textField.text, forKey: Config.lastJoinedRoomKey)
        
        ProgressHUD.show()
        roomManager.joinRoom(room: roomID)
    }
    
    @IBAction func segmentAction(_ sender: UISegmentedControl) {
        /// index = 0, Share Camera Content, index = 1, Share Screen Content
        let index = sender.selectedSegmentIndex
        let titles = ["Publisher", "Subscriber"]
        let selectedTitle = titles[index]
        ProgressHUD.show(selectedTitle, icon: .star)
        roomManager.shouldJoinedAsPubliherAtFirstTime = selectedTitle == "Publisher"
    }
    
    private func sendActionForBroadcastPicker() {
        broadcastPicker.subviews.compactMap({ $0 as? UIButton }).forEach { (button) in
            button.sendActions(for: .allEvents)
        }
    }
}

extension ViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        joinAction(joinButton)
        return true
    }
}
