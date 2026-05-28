# LeSci iOS 版本源码

这是 LeSci 的 iOS 重写版源码，使用 SwiftUI + WKWebView 实现。当前目录不是由 APK 自动转换而来，而是按 Android 版已验证的接口重新实现了一套 iOS 客户端。

## 已实现

- 京东登录页内嵌打开，默认进入京东登录注册页面。
- 自动从 WKWebView Cookie 中识别 `pt_key` 和 `pt_pin`。
- 登录成功后调用 `/android/ck` 上传账号数据。
- 打开 App 后自动调用 `/android/accounts` 和 `/android/bean-stats` 刷新账号、资产、有效状态。
- 服务器失联时不展示服务器地址，只提示“服务器已失联”，并保留本地缓存账号。
- 支持 `/android/app-control` 远程控制停服、升级提示。
- 首页账号状态条、账号卡片、展开资产、左滑隐藏账号显示。
- 点击头像查看神秘数据，支持复制。
- 已添加账号后，在添加按钮上方显示 QQ/微信机器人联系方式，点击可复制。

## 在 Mac 上打开

方式一：用 XcodeGen 生成工程。

```bash
cd LeSci-iOS
brew install xcodegen
xcodegen generate
open LeSci.xcodeproj
```

## 在 Mac 上导出 IPA

需要 Apple 开发者账号，并在 Xcode 登录该账号。然后执行：

```bash
cd LeSci-iOS
TEAM_ID=你的开发者TeamID ./build_ipa_on_mac.sh
```

成功后 IPA 会在：

```text
LeSci-iOS/build/export/LeSci.ipa
```

## 生成全能签可用的未签名 IPA

如果你没有 Mac，可以把整个 `LeSci-iOS` 目录上传到 GitHub 仓库，然后打开：

```text
Actions -> Build Unsigned IPA -> Run workflow
```

跑完后在 Artifacts 下载 `LeSci-unsigned-ipa`，里面的 `LeSci-unsigned.ipa` 就可以拿去全能签签名。

方式二：不用 XcodeGen。

1. 打开 Xcode，新建 iOS App。
2. Product Name 填 `LeSci`，Interface 选 SwiftUI，Language 选 Swift。
3. 删除默认生成的 Swift 文件。
4. 把 `LeSci` 文件夹里的 `.swift`、`LeSci-Info.plist`、`Assets.xcassets` 拖入项目。
5. 在 Target 设置里把 Info.plist 指向 `LeSci/LeSci-Info.plist`。

## 打包前注意

- iOS 必须在 macOS + Xcode + Apple 开发者账号环境下签名打包，Windows 这里不能直接生成可安装 IPA。
- 当前接口仍然使用 `http://236788.xyz:9091`，源码里已允许 HTTP 访问。正式上架或长期使用建议换 HTTPS。
- Bundle Identifier 当前是 `com.joysync.lesci`，真机安装前请在 Xcode 里改成你自己的唯一 ID，并选择签名 Team。
- App 图标目录已经预留，发布前请在 `Assets.xcassets/AppIcon.appiconset` 里补完整图标。

## 关键文件

- `LeSci/ContentView.swift`：首页 UI、账号卡片、联系方式、神秘数据弹窗。
- `LeSci/JDLoginView.swift`：京东登录 WebView、QQ scheme 处理、Cookie 检测。
- `LeSci/AccountStore.swift`：本地缓存、启动刷新、上传账号、隐藏账号显示。
- `LeSci/LeSciAPI.swift`：BNCR/服务器接口。
- `LeSci/LeSciConfig.swift`：服务器、登录地址、机器人联系方式。
