import UIKit
import AVKit
import AVFoundation

/// 画中画管理器 - 将记牌数据绘制成视频帧并显示在小窗中
class PiPManager: NSObject {

    static let shared = PiPManager()

    private var pipController: AVPictureInPictureController?
    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    private var renderTimer: Timer?
    private var readinessObservation: NSKeyValueObservation?
    private var starting = false
    var onStateChange: ((String, Bool, Bool) -> Void)?

    /// 画中画渲染尺寸（小窗实际显示尺寸由系统决定，这里是渲染分辨率）
    private let renderSize = CGSize(width: 360, height: 480)

    private override init() {
        super.init()
    }

    // MARK: - 启动/停止

    func prepare(in preview: UIView) {
        guard pipController == nil else { return }
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            onStateChange?("此设备不支持画中画", false, false)
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            onStateChange?("音频会话失败：\(error.localizedDescription)", false, false)
            return
        }
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspect
        layer.frame = preview.bounds
        preview.layer.addSublayer(layer)
        sampleBufferDisplayLayer = layer
        var timebase: CMTimebase?
        if CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault,
            sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase) == noErr,
            let timebase = timebase {
            CMTimebaseSetTime(timebase, time: CMClockGetTime(CMClockGetHostTimeClock()))
            CMTimebaseSetRate(timebase, rate: 1)
            layer.controlTimebase = timebase
        }
        let controller = AVPictureInPictureController(
            contentSource: .init(sampleBufferDisplayLayer: layer, playbackDelegate: self))
        controller.delegate = self
        controller.requiresLinearPlayback = true
        pipController = controller
        readinessObservation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.reportReadiness() }
        }
        // Feed the layer before requesting PiP, including when capture has not started.
        renderTick()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.renderTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        renderTimer = timer
    }

    func resizePreview(to bounds: CGRect) {
        sampleBufferDisplayLayer?.frame = bounds
    }

    private func reportReadiness() {
        guard let controller = pipController,
              !controller.isPictureInPictureActive, !starting else { return }
        let ready = controller.isPictureInPicturePossible
        onStateChange?(ready ? "已就绪，请点击启动" : "等待系统允许画中画", ready, false)
    }

    func startPictureInPicture() {
        guard let controller = pipController, !starting,
              !controller.isPictureInPictureActive else { return }
        guard controller.isPictureInPicturePossible else {
            reportReadiness()
            return
        }
        starting = true
        onStateChange?("正在启动", false, false)
        controller.startPictureInPicture()
    }

    func stopPictureInPicture() {
        pipController?.stopPictureInPicture()
    }

    private func renderTick() {
        guard let layer = sampleBufferDisplayLayer else { return }
        if layer.status == .failed { layer.flush() }
        guard layer.isReadyForMoreMediaData else { return }
        let defaults = UserDefaults(suiteName: AppGroupConstants.appGroupID)
        let frameCount = defaults?.integer(forKey: AppGroupConstants.Keys.frameCount) ?? 0
        let isBroadcasting = defaults?.bool(forKey: AppGroupConstants.Keys.isBroadcasting) ?? false
        if let sample = renderCardCounterFrame(frameCount: frameCount, isBroadcasting: isBroadcasting) {
            layer.enqueue(sample)
        }
    }

    // MARK: - 渲染记牌面板

    /// 将记牌数据绘制成一帧 CMSampleBuffer
    private func renderCardCounterFrame(frameCount: Int, isBroadcasting: Bool) -> CMSampleBuffer? {
        let size = renderSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            let cgContext = context.cgContext

            // 背景
            UIColor.black.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))

            // 半透明面板
            let panelRect = CGRect(x: 8, y: 8, width: size.width - 16, height: size.height - 16)
            let panelPath = UIBezierPath(roundedRect: panelRect, cornerRadius: 12)
            UIColor(white: 0.1, alpha: 0.9).setFill()
            panelPath.fill()

            // 标题
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.white
            ]
            ("够级记牌器 · 示例数据" as NSString).draw(
                at: CGPoint(x: 20, y: 20),
                withAttributes: titleAttrs
            )

            // 状态
            let statusText = isBroadcasting ? "采集中" : "待采集"
            let statusColor = isBroadcasting ? UIColor.systemGreen : UIColor.systemOrange
            let statusAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: statusColor
            ]
            (statusText as NSString).draw(
                at: CGPoint(x: size.width - 80, y: 22),
                withAttributes: statusAttrs
            )

            // 分隔线
            UIColor.darkGray.setStroke()
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: 20, y: 48))
            linePath.addLine(to: CGPoint(x: size.width - 20, y: 48))
            linePath.lineWidth = 1
            linePath.stroke()

            // 玩家剩余张数（5个玩家）
            let playerLabels = ["对门", "上联", "下联", "上家", "下家"]
            let playerCounts = [51, 51, 51, 51, 51] // 测试数据

            for (index, label) in playerLabels.enumerated() {
                let yOffset: CGFloat = 60 + CGFloat(index) * 32

                // 玩家位置标签
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.lightGray
                ]
                (label as NSString).draw(
                    at: CGPoint(x: 20, y: yOffset + 4),
                    withAttributes: labelAttrs
                )

                // 剩余张数
                let countAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.white
                ]
                let countText = "\(playerCounts[index])张"
                (countText as NSString).draw(
                    at: CGPoint(x: size.width - 80, y: yOffset + 4),
                    withAttributes: countAttrs
                )
            }

            // 分隔线
            UIColor.darkGray.setStroke()
            let line2 = UIBezierPath()
            line2.move(to: CGPoint(x: 20, y: 230))
            line2.addLine(to: CGPoint(x: size.width - 20, y: 230))
            line2.lineWidth = 1
            line2.stroke()

            // 牌面剩余数量（网格显示）
            let cardNames = ["3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A", "2", "小王", "大王"]
            let cardCounts = [6, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 6, 6] // 初始值
            let cols = 3
            let cellWidth: CGFloat = (size.width - 40) / CGFloat(cols)
            let cellHeight: CGFloat = 32

            for (index, name) in cardNames.enumerated() {
                let col = index % cols
                let row = index / cols
                let x = 20 + CGFloat(col) * cellWidth
                let y: CGFloat = 240 + CGFloat(row) * cellHeight

                let nameAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.lightGray
                ]
                (name as NSString).draw(at: CGPoint(x: x, y: y + 6), withAttributes: nameAttrs)

                let countAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 13),
                    .foregroundColor: UIColor.white
                ]
                let countText = "\(cardCounts[index])"
                let textSize = (countText as NSString).size(withAttributes: countAttrs)
                (countText as NSString).draw(
                    at: CGPoint(x: x + cellWidth - textSize.width - 10, y: y + 6),
                    withAttributes: countAttrs
                )
            }

            // 底部调试信息
            let debugAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            let debugText = "采集帧: \(frameCount) | 刷新: \(Int(Date().timeIntervalSince1970) % 10000)"
            (debugText as NSString).draw(
                at: CGPoint(x: 20, y: size.height - 24),
                withAttributes: debugAttrs
            )
        }

        // 将 UIImage 转换为 CVPixelBuffer，再包装成 CMSampleBuffer
        guard let cgImage = image.cgImage else { return nil }
        return makeSampleBuffer(from: cgImage)
    }

    private func makeSampleBuffer(from cgImage: CGImage) -> CMSampleBuffer? {
        let width = cgImage.width
        let height = cgImage.height

        // 创建 pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true
            ] as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])

        // 包装成 CMSampleBuffer
        var formatDesc: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescriptionOut: &formatDesc
        )
        guard let format = formatDesc else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 10),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        return sampleBuffer
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PiPManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiP will start")
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        starting = false
        onStateChange?("已启动", false, true)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    failedToStartPictureInPictureWithError error: Error) {
        starting = false
        onStateChange?("启动失败：\(error.localizedDescription)", pictureInPictureController.isPictureInPicturePossible, false)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        starting = false
        onStateChange?("已停止，可重新启动", pictureInPictureController.isPictureInPicturePossible, false)
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

extension PiPManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    setPlaying playing: Bool) {
        // 我们不是播放视频，忽略播放控制
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        // 返回一个大范围，表示"持续播放"
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        // 渲染尺寸变化
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    skipByInterval skipInterval: CMTime,
                                    completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
