//
//  VideoRoomCollectionViewCell.swift
//  janus-videoroom-example
//
//  Created by Meonardo on 2021/4/21.
//

import UIKit
import WebRTC

class VideoRoomCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "VideoRoomCollectionViewCell"
    
    weak var renderView: RTCMTLVideoView?
    
    required init?(coder: NSCoder) {
        fatalError("Please Use Init with Indentifier")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor  = .clear
        contentView.backgroundColor = .clear
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
    func update(with connection: JanusConnection) {
        renderView?.removeFromSuperview()
        
        let renderView = RTCMTLVideoView(frame: contentView.bounds)
        renderView.videoContentMode = .scaleAspectFill
        renderView.layer.cornerRadius = 4
        renderView.layer.masksToBounds = true
        contentView.addSubview(renderView)
        
        self.renderView = renderView
        
        /// Attach Renderer to New Source
        connection.rtcClient?.detach(renderer: renderView, isLocal: connection.isLocal)
        connection.rtcClient?.attach(renderer: renderView, isLocal: connection.isLocal)
    }
}
