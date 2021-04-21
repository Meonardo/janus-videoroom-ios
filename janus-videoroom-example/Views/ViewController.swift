//
//  ViewController.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/20.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet private weak var textField: UITextField!
    @IBOutlet private weak var joinButton: UIButton!
    @IBOutlet private weak var stackView: UIStackView!
    @IBOutlet private weak var segmentControl: UISegmentedControl!
    @IBOutlet private weak var websocketStatusLabel: UILabel!
    
    static let lastJoinedRoomKey = "kLastJoinedRoomKey"
    
    private var roomManager: JanusRoomManager {
        JanusRoomManager.shared
    }
    
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
        
        textField.text = UserDefaults.standard.string(forKey: Self.lastJoinedRoomKey)
        
        roomManager.connect()
    }
    
    private func addNotificationObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(signalingStateChange(_:)), name: JanusRoomManager.signalingStateChangeNote, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(roomStateChange(_:)), name: JanusRoomManager.roomStateChangeNote, object: nil)
    }
    
    @objc private func signalingStateChange(_ sender: Notification) {
        guard let state = sender.object as? WebSocketConnectState else { return }
        
        switch state {
        case .connected:
            websocketStatusLabel.text = "Connected"
            websocketStatusLabel.textColor = UIColor.systemGreen
        case .cancelled:
            websocketStatusLabel.text = "Cancelled"
            websocketStatusLabel.textColor = UIColor.systemOrange
        case .disconnected(let reason, let code):
            websocketStatusLabel.text = "Disconnected with: \(reason), code: \(code)"
            websocketStatusLabel.textColor = UIColor.systemOrange
        case .error(let err):
            websocketStatusLabel.text = "Error \(err?.localizedDescription ?? "No Reason")"
            websocketStatusLabel.textColor = UIColor.systemRed
        }
    }
    
    @objc private func roomStateChange(_ sender: Notification) {
        guard let isDestroy = sender.object as? Bool else { return }
        
        ProgressHUD.dismiss()
        if isDestroy {
            joinButton.isEnabled = true
        } else {
            /// Save for next launch
            UserDefaults.standard.setValue(textField.text, forKey: Self.lastJoinedRoomKey)
            
            joinButton.isEnabled = false
            let video = VideoRoomViewController.showVideo()
            video.modalPresentationStyle = .currentContext
            present(video, animated: true, completion: nil)
        }
    }
}

/// Actions
extension ViewController {
    
    @IBAction private func joinAction(_ sender: UIButton) {
        guard let text = textField.text, let roomID = Int(text) else {
            ProgressHUD.showError("Room Number Must be an Integer")
            return
        }
        sender.isEnabled = false
        ProgressHUD.show()
        
        roomManager.createRoom(room: roomID)
    }
    
    @IBAction func segmentAction(_ sender: UISegmentedControl) {
        /// index = 0, Share Camera Content, index = 1, Share Screen Content
        print(sender.selectedSegmentIndex)
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
