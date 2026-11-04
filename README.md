# 中译英键盘（iOS 自定义输入法扩展）

在 iOS 自定义键盘里打拼音 → 候选栏显示中文词 → 键盘下方实时显示英文翻译。
支持全拼（`jintianwanshang`）、声母简拼（`jintianwans` → 今天晚上）和输入中途联想（`jinti` → 今天）。

## 项目结构

```
ios-zh2en-keyboard/
├── ChineseTranslateKeyboard.xcodeproj/   # Xcode 工程（App + 键盘扩展双 target）
├── App/                                  # 主 App（引导页 + 试用输入框）
│   ├── ChineseTranslateKeyboardApp.swift
│   ├── ContentView.swift
│   └── Info.plist
└── Keyboard/                             # 键盘扩展（核心）
    ├── KeyboardViewController.swift      # 键盘 UI + 输入逻辑
    ├── PinyinComposer.swift              # 拼音组词引擎（全拼/简拼/联想）
    ├── TranslationService.swift          # 在线整句翻译（MyMemory 免费 API）
    ├── pinyin_dict.json                  # 内置词库（词 + 拼音 + 英文释义）
    └── Info.plist                        # RequestsOpenAccess / NSExtension 配置
```

## 实现原理

| 需求 | 实现方式 |
|---|---|
| 自定义键盘 | App Extension（`com.apple.keyboard-service`），`UIInputViewController` 子类纯代码搭建 UI |
| 中文候选栏 | 内置词库 `pinyin_dict.json` + 拼音匹配引擎（全拼/声母简拼/末音节截断联想），纯离线 |
| 下方英文翻译 | ① 离线：候选词自带英文释义，逐词拼接显示；② 在线：开启「允许完全访问」后调 MyMemory API 整句翻译 |
| 上屏 | `textDocumentProxy.insertText()` 写入宿主 App 输入框 |

## 编译运行（需要 Mac + Xcode 15+）

> 注意：iOS 项目只能在 macOS 的 Xcode 里编译，Windows 上无法构建。可以把目录推到 GitHub，用 Mac 或 Codemagic 云构建。

1. 双击打开 `ChineseTranslateKeyboard.xcodeproj`
2. 选中项目 → 每个 target 的 **Signing & Capabilities → Team** 选你的 Apple ID（免费 Personal Team 即可）
3. 顶部选 `ChineseTranslateKeyboard` scheme + 真机/模拟器，⌘R 运行
4. 首次运行真机需：设置 → 通用 → VPN与设备管理 → 信任开发者证书

## 启用键盘（装到手机后）

1. 设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → 选「中译英键盘」
2. 点进该键盘 → 打开 **允许完全访问**（在线翻译必需，离线词库翻译不依赖它）

## 自定义

- **扩词库**：往 `Keyboard/pinyin_dict.json` 加条目即可，格式 `{"h":"词","p":["pin","yin"],"e":"english"}`，顺序即同分候选优先级
- **换翻译 API**：改 `Keyboard/TranslationService.swift` 的 `translate()`（有道/百度/DeepL 都行）
- **改键盘外观**：`KeyboardViewController.swift` 的 `rebuildRows()` / `makeKey()`

## 已知限制

- 内置词库约 160 条，仅覆盖常用词；做产品需接入完整拼音词典（如开源 libpinyin 词库转换成 JSON）
- iOS 对键盘扩展有 ~60-70MB 内存限制，词库不宜整块加载过大，量大时需改 SQLite 按需查询
- 键盘扩展默认不能联网，必须用户手动开「允许完全访问」
- 上架 App Store 需要补 App Icon（Assets.xcassets）和隐私说明
