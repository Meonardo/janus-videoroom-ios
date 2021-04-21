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
    
    var renderView: RTCMTLVideoView
    
    required init?(coder: NSCoder) {
        fatalError("Please Use Init with Indentifier")
    }
    
    override init(frame: CGRect) {
        renderView = RTCMTLVideoView(frame: frame)
        renderView.videoContentMode = .scaleAspectFill
        renderView.layer.cornerRadius = 4
        renderView.layer.masksToBounds = true
        
        super.init(frame: frame)
        backgroundColor  = .clear
        contentView.backgroundColor = .clear
        contentView.addSubview(renderView)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
