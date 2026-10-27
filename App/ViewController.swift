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
    private let preview = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "够级记牌器"
        setupUI()
        pipManager.onStateChange = { [weak self] message, canStart, canStop in
            self?.statusLabel.text = "画中画：" + message
            self?.startButton.isEnabled = canStart
            self?.stopButton.isEnabled = canStop
        }
        startObservingBroadcastData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.layoutIfNeeded()
        pipManager.prepare(in: preview)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pipManager.resizePreview(to: preview.bounds)
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -32)
        ])

        let titleLabel = UILabel()
        titleLabel.text = "够级记牌器 - 测试版"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        stack.addArrangedSubview(titleLabel)

        statusLabel = UILabel()
        statusLabel.text = "画中画：准备中"
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(statusLabel)

        frameCountLabel = UILabel()
        frameCountLabel.text = "采集帧数：--"
        frameCountLabel.font = .systemFont(ofSize: 16)
        frameCountLabel.textColor = .secondaryLabel
        stack.addArrangedSubview(frameCountLabel)
        preview.backgroundColor = .black
        preview.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(preview)
        NSLayoutConstraint.activate([
            preview.widthAnchor.constraint(equalToConstant: 90),
            preview.heightAnchor.constraint(equalToConstant: 120)
        ])

        startButton = UIButton(type: .system)
        startButton.setTitle("启动画中画", for: .normal)
        startButton.isEnabled = false
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
        tipLabel.text = "使用说明：\n1. 点击\"启动画中画\"\n2. 打开控制中心，长按录屏按钮\n3. 选择\"够级记牌器\"，开始直播\n4. 切回游戏，观察小窗帧数和刷新数字\n当前只测试采集和画中画，牌数为示例数据"
        tipLabel.numberOfLines = 0
        tipLabel.textAlignment = .center
        tipLabel.font = .systemFont(ofSize: 14)
        tipLabel.textColor = .tertiaryLabel
        stack.addArrangedSubview(tipLabel)
    }

    @objc private func startTapped() {
        pipManager.startPictureInPicture()
    }

    @objc private func stopTapped() {
        pipManager.stopPictureInPicture()
    }

    /// 定时从 App Group 读取广播扩展的数据
    private func startObservingBroadcastData() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateBroadcastStatus()
        }
    }

    private func updateBroadcastStatus() {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupConstants.appGroupID) != nil else {
            frameCountLabel.text = "共享空间不可用：需检查签名权限"
            frameCountLabel.textColor = .systemRed
            return
        }
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
