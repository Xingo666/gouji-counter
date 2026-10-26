# 够级记牌器 - iOS 测试版

多乐够级自动记牌器，通过屏幕采集识别出牌，画中画显示记牌结果。

## 当前版本

**v0.1.0 (测试版)** - 仅验证基础链路：
- ✅ 画中画（PiP）窗口能否悬浮显示
- ✅ 屏幕广播扩展能否采集画面
- ⏳ 记牌识别逻辑（后续版本）

## 项目结构

```
gouji-counter/
├── App/                    # 主应用
│   ├── AppDelegate.swift
│   ├── ViewController.swift    # 主界面
│   ├── PiPManager.swift        # 画中画管理器
│   └── Info.plist
├── BroadcastExtension/     # 屏幕广播扩展
│   ├── SampleHandler.swift     # 帧采集处理
│   └── Info.plist
├── Shared/                 # 共享代码
│   └── AppGroupConstants.swift
├── GoujiCardCounter.entitlements
├── BroadcastExtension.entitlements
├── project.yml             # xcodegen 项目配置
└── .github/workflows/
    └── build.yml           # 云端构建
```

## 构建方式

### 方式一：GitHub Actions 云端构建（推荐，无需 Mac）

1. 将本项目推送到 GitHub 仓库
2. 触发 Actions 中的 "Build iOS App" 工作流
3. 从 Artifacts 下载 `GoujiCardCounter.ipa`

### 方式二：本地 Xcode 构建（需要 Mac）

```bash
brew install xcodegen
cd gouji-counter
xcodegen generate
open GoujiCardCounter.xcodeproj
```

## 安装到 iPhone（AltStore）

### 前置条件
- Windows 已安装 AltServer
- iPhone 已安装 AltStore Classic
- 手机与电脑在同一 Wi-Fi，或用数据线连接

### 安装步骤
1. 下载 `GoujiCardCounter.ipa` 到电脑
2. 确保 AltServer 正在运行
3. 点击系统托盘 AltServer 图标 → Install AltStore → 你的 iPhone（先确认 AltStore 已安装）
4. 将 IPA 拖入 iTunes 或通过 AltStore 的 "My Apps" 页面安装
5. 手机上打开设置 → 通用 → VPN与设备管理 → 信任开发者

### 或者直接在手机 AltStore 中安装
1. 将 IPA 上传到手机（AirDrop / 文件 App）
2. 打开 AltStore → My Apps → 点击 + 号 → 选择 IPA 文件
3. 输入 Apple ID 密码开始安装

## 使用方法

1. 打开"够级记牌器"App
2. 点击"启动画中画"按钮
3. 打开控制中心（从屏幕右上角向下滑）
4. 长按录屏按钮
5. 选择"够级记牌器"，点击"开始直播"
6. 切回多乐够级游戏
7. 画中画小窗会显示记牌面板

## 已知限制（测试版）

- 记牌数据为固定初始值，尚未接入实际识别
- App Group 数据共享可能需要完整开发者签名
- PiP 窗口大小和位置由系统控制

## 后续计划

- [ ] 接入卡牌识别（OpenCV / Vision）
- [ ] 识别玩家出牌并计数
- [ ] 买3买4阶段处理
- [ ] 开点、烧牌规则
- [ ] 手动纠错功能
