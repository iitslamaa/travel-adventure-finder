//
//  VideoBackgroundView.swift
//  TravelScoreriOS
//

import SwiftUI
import AVKit

struct VideoBackgroundView: UIViewRepresentable {
    let videoName: String
    let videoType: String
    let loop: Bool
    var onFinished: (() -> Void)? = nil   // NEW

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.onFinished = onFinished      // NEW
        view.load(videoName: videoName, videoType: videoType, loop: loop)
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.onFinished = onFinished    // keep closure updated
        uiView.updateIfNeeded(videoName: videoName, videoType: videoType, loop: loop)
    }
}

final class PlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var player: AVPlayer?
    private var currentKey: String?
    private var currentItem: AVPlayerItem?
    private var shouldLoop: Bool = false

    var onFinished: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func load(videoName: String, videoType: String, loop: Bool) {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        let key = "\(videoName).\(videoType)-loop:\(loop)"
        currentKey = key
        shouldLoop = loop
        alpha = 1

        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoType) else {
            assertionFailure("Missing bundled video: \(videoName).\(videoType)")
            return
        }

        let item = AVPlayerItem(url: url)
        currentItem = item

        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = loop ? .none : .pause

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVideoFinished(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        self.player = player
        playerLayer.player = player
        player.play()
    }

    func updateIfNeeded(videoName: String, videoType: String, loop: Bool) {
        let newKey = "\(videoName).\(videoType)-loop:\(loop)"
        guard newKey != currentKey else { return }

        player?.pause()
        currentItem = nil
        player = nil

        load(videoName: videoName, videoType: videoType, loop: loop)
    }

    @objc private func handleVideoFinished(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem else { return }

        if shouldLoop {
            // Looping videos should never fade out — restart playback.
            item.seek(to: .zero, completionHandler: nil)
            player?.play()
            return
        }

        player?.pause()

        // Trigger routing immediately
        onFinished?()

        // Fade out in parallel (prevents perceived lag)
        UIView.animate(withDuration: 0.15) {
            self.alpha = 0
        }
    }

    deinit {
        playerLayer.player = nil
        player = nil
        currentItem = nil
        NotificationCenter.default.removeObserver(self)
    }
}
