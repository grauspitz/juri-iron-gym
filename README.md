# 蛛莉铁馆

一款基于 SwiftUI 的 iOS 杠铃训练记录应用，提供配重管理、训练记录、休息计时和游戏机风格的训练界面。

**设备适配：主要面向 iPhone Duo，其他机型尚未做适配。**

## 主要功能

- 管理杠铃片规格和杆重，调整配重并记录每组重量、次数和动作。
- 制定训练计划，查看训练历史、日历和统计信息。
- 设置组间休息计时，并通过通知、桌面小组件和实时活动查看训练状态。
- 在 iPhone Duo 上使用横屏或竖屏训练模式。
- 导出和恢复 JSON 备份，可读取 Apple 健康中的训练能量数据。
- 根据近期训练记录生成训练建议（需要配置智谱 API 密钥）。

## 运行项目

1. 使用 Xcode 打开 `BarbellTraining.xcodeproj`。
2. 选择 `BarbellTraining` 运行目标及模拟器或已连接的 iPhone。
3. 在 **Signing & Capabilities** 中配置自己的开发团队；如有需要，调整 App 和 Widget 的 Bundle Identifier、App Groups 及相关签名配置。
4. 运行项目。主应用的部署目标为 iOS 16.0，小组件目标为 iOS 17.0；部分功能依赖设备和系统能力。

Apple 健康、通知和实时活动等功能需要相应系统授权或设备支持，实际表现以设备设置为准。

## 配置训练建议

训练建议使用智谱 API。若不需要此功能，可以跳过密钥配置。

在 `BarbellTraining` 目录下创建 `Secrets.local.xcconfig`：

```xcconfig
TRAINING_ADVICE_API_KEY = 在此填写自己的密钥
```

`TrainingConfig.xcconfig` 会在构建时读取该本地文件；它已加入 `.gitignore`，不要将密钥提交到仓库。未配置密钥时，训练建议会提示未配置。

训练建议会将最近 30 天内最多 150 组训练记录发送至智谱服务。当前实现会将密钥写入 App 的构建产物，不能视为安全的密钥存储方案；发布前应改为通过服务端代理请求，并妥善管理密钥。

## 项目结构

```text
BarbellTraining.xcodeproj/  Xcode 项目配置
BarbellTraining/            主应用、训练界面、资源和数据逻辑
BarbellWidget/              小组件和实时活动相关代码
```

训练数据保存在本机；恢复备份会覆盖当前数据，操作前建议先导出备份。
