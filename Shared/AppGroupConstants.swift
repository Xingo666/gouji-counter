import Foundation

/// App Group 标识，用于主 App 和广播扩展之间共享数据
/// 注意：实际使用时需要与你的开发者账号 Team ID 匹配
/// 格式：group.<bundle-id-prefix>.goujicounter
enum AppGroupConstants {
    /// App Group identifier - 需与项目配置一致
    static let appGroupID = "group.com.goujicounter.shared"

    /// UserDefaults 中的键名
    enum Keys {
        /// 广播扩展收到的帧数
        static let frameCount = "frame_count"
        /// 广播状态
        static let isBroadcasting = "is_broadcasting"
        /// 最后更新时间戳
        static let lastUpdateTime = "last_update_time"
        /// 记牌数据（JSON 字符串）
        static let cardData = "card_data"
    }
}

/// 记牌数据模型 - 用于主 App 和扩展之间传递
struct CardCounterData: Codable {
    /// 其他5人各自的剩余手牌数
    var playerRemainingCards: [Int] = [0, 0, 0, 0, 0]
    /// 各牌面剩余数量（按 3,4,5,6,7,8,9,10,J,Q,K,A,2,小王,大王 顺序）
    var cardRemaining: [Int] = Array(repeating: 0, count: 15)
    /// 帧数（用于调试）
    var frameCount: Int = 0
}
