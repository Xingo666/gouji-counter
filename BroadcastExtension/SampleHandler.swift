import ReplayKit
import UIKit

/// 屏幕广播扩展 - 接收系统屏幕录制的视频帧
/// 用户在控制中心启动录屏并选择本应用时，这里会收到画面
class SampleHandler: RPBroadcastSampleHandler {

    private var frameCount: Int = 0
    private var lastSaveTime: TimeInterval = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // 用户开始了屏幕广播
        print("Broadcast started")
        frameCount = 0
        saveStatus(isBroadcasting: true, frameCount: 0)
    }

    override func broadcastPaused() {
        // 用户暂停了广播
        print("Broadcast paused")
    }

    override func broadcastResumed() {
        // 用户恢复了广播
        print("Broadcast resumed")
    }

    override func broadcastFinished() {
        // 用户结束了广播
        print("Broadcast finished")
        saveStatus(isBroadcasting: false, frameCount: frameCount)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                     with sampleBufferType: RPSampleBufferType) {
        // 收到一帧画面
        switch sampleBufferType {
        case .video:
            frameCount += 1

            // 限制保存频率（每 10 帧更新一次，避免频繁 I/O）
            let now = Date().timeIntervalSince1970
            if now - lastSaveTime > 0.2 {
                lastSaveTime = now
                saveStatus(isBroadcasting: true, frameCount: frameCount)
            }

            // TODO: 后续在这里加入卡牌识别逻辑
            // 从 sampleBuffer 提取图像 -> 识别各玩家出牌 -> 更新记牌数据

        case .audioApp, .audioMic:
            // 音频数据暂时忽略
            break
        @unknown default:
            break
        }
    }

    // MARK: - 保存状态到 App Group

    private func saveStatus(isBroadcasting: Bool, frameCount: Int) {
        guard let defaults = UserDefaults(suiteName: AppGroupConstants.appGroupID) else {
            print("Warning: Cannot access App Group UserDefaults")
            return
        }
        defaults.set(isBroadcasting, forKey: AppGroupConstants.Keys.isBroadcasting)
        defaults.set(frameCount, forKey: AppGroupConstants.Keys.frameCount)
        defaults.set(Date().timeIntervalSince1970, forKey: AppGroupConstants.Keys.lastUpdateTime)
        defaults.synchronize()
    }
}
