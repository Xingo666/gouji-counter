import UIKit
import AVKit
import AVFoundation

/// 主界面 - 控制画中画显示和查看状态
class ViewController: UIViewController {

    private let pipManager = PiPManager.shared
    private var statusLabel: UILabel!
    private var frameCountLabel: UILabel!
    private var startButton: UIButton!
    private var stopButton: UIButton!
    private var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "够级记牌器"
        setupUI()
        startObservingBroadcastData()
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        let titleLabel = UILabel()
        titleLabel.text = "够级记牌器 - 测试版"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        stack.addArrangedSubview(titleLabel)

        statusLabel = UILabel()
        statusLabel.text = "画中画：未启动"
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(statusLabel)

        frameCountLabel = UILabel()
        frameCountLabel.text = "采集帧数：--"
        frameCountLabel.font = .systemFont(ofSize: 16)
        frameCountLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(frameCountLabel)

        startButton = UIButton(type: .system)
        startButton.setTitle("启动画中画", for: .normal)
        startButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        stack.addArrangedSubview(startButton)

        stopButton = UIButton(type: .system)
        stopButton.setTitle("停止画中画", for: .normal)
        stopButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        stopButton.isEnabled = false
        stack.addArrangedSubview(stopButton)

        let tipLabel = UILabel()
        tipLabel.text = "使用说明：\n1. 点击\"启动画中画\"\n2. 打开控制中心，长按录屏按钮\n3. 选择\"够级记牌器\"，开始直播\n4. 切回游戏，小窗会显示记牌数据"
        tipLabel.numberOfLines = 0
        tipLabel.textAlignment = .center
        tipLabel.font = .systemFont(ofSize: 14)
        tipLabel.textColor = .tertiaryLabel
        stack.addArrangedSubview(tipLabel)
    }

    @objc private func startTapped() {
        pipManager.startPictureInPicture()
        statusLabel.text = "画中画：已启动"
        startButton.isEnabled = false
        stopButton.isEnabled = true
    }

    @objc private func stopTapped() {
        pipManager.stopPictureInPicture()
        statusLabel.text = "画中画：已停止"
        startButton.isEnabled = true
        stopButton.isEnabled = false
    }

    /// 定时从 App Group 读取广播扩展的数据
    private func startObservingBroadcastData() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateBroadcastStatus()
        }
    }

    private func updateBroadcastStatus() {
        guard let defaults = UserDefaults(suiteName: AppGroupConstants.appGroupID) else {
            return
        }
        let frameCount = defaults.integer(forKey: AppGroupConstants.Keys.frameCount)
        let isBroadcasting = defaults.bool(forKey: AppGroupConstants.Keys.isBroadcasting)

        DispatchQueue.main.async {
            self.frameCountLabel.text = isBroadcasting
                ? "采集帧数：\(frameCount)"
                : "屏幕采集：未启动"
            self.frameCountLabel.textColor = isBroadcasting ? .systemGreen : .secondaryLabel
        }
    }

    deinit {
        timer?.invalidate()
    }
}
