# ADR-0004：批准 Android 通知采集能力

- 状态：Accepted
- 日期：2026-08-24
- 决策者：项目所有者

## 背景

项目所有者已批准进入自动记账实现阶段。Android 的 `NotificationListenerService` 能在用户于系统设置中显式授权后接收其他应用发布、更新和移除的通知，适合作为默认低侵入数据源。该能力会接触金融通知文本，因此必须先冻结权限、采集、存储和降级边界。

官方依据：

- [NotificationListenerService](https://developer.android.com/reference/android/service/notification/NotificationListenerService)
- [通知监听授权设置](https://developer.android.com/reference/android/provider/Settings)
- [Android Manifest 合并](https://developer.android.com/build/manage-manifests)
- [Android Auto Backup](https://developer.android.com/identity/data/autobackup)
- [Android 15 OTP 脱敏](https://developer.android.com/about/versions/15/behavior-changes-all#otp-redaction)

## 决策

### 权限与启用

- 通知自动记账总开关、通知来源开关和每个来源应用开关默认关闭。
- `BIND_NOTIFICATION_LISTENER_SERVICE` 只声明在 Android Flutter plugin 的 library manifest 中，通过 manifest merge 进入宿主；不修改 BeeCount `MainActivity` 或宿主 manifest。
- 授权只能由用户主动进入系统“通知使用权”设置完成。拒绝、取消或撤回后立即停止采集，不循环弹窗，不自动启用无障碍、短信、截图、Shizuku 或 Root。
- Android 27+ 使用 `NotificationManager.isNotificationListenerAccessGranted` 检查状态；旧版本安全降级到系统已启用 listener 列表。

### 采集与来源限制

- 原生 listener 必须在读取正文前检查总开关、通知能力开关和已启用包名白名单。
- 首批登记微信、支付宝、云闪付、小米钱包、京东、美团、抖音、淘宝；银行应用必须逐个登记和验证，不提供“读取所有应用”开关。
- 每条通知最多读取标题、正文、展开正文、副标题和文本行中的有限字符；不读取图片、RemoteViews、联系人、附件、完整 extras 或其他无关字段。
- 回调主线程只做白名单判断和有界字段复制，队列 I/O 在单线程 executor 中完成。
- 同一 notification key 的再次发布视为更新；移除只记录生命周期，不解释为退款、撤销或反向交易。
- Android 15 或 ROM 脱敏导致字段缺失时，事件进入待确认或忽略，不尝试绕过系统保护。

### 身份、队列与存储

- notification key 只存在于内存或加密 payload；进入 Dart 候选前使用 Android Keystore HMAC-SHA256 令牌化。
- 原始恢复 payload 使用 Android Keystore AES-256-GCM 加密，存放在 `noBackupFilesDir`，不进入 Android Auto Backup、BeeCount 云同步、导出或日志。
- 队列实现 ADR-0003 的至少一次交付、租约、部分确认、退避、死信和最长 24 小时绝对 TTL；成功解析后立即销毁原始 payload。
- 日志只允许非敏感机器码、数量、状态和耗时，不得包含标题、正文、商户、金额、账号、notification key 或 HMAC。

### 处理时机

- 首个可安装版本不启动常驻 Flutter 后台引擎。原生 listener 在应用未打开时安全排队；BeeCount 启动或恢复前台后由 Bundle 排空队列、解析、去重并按 Core 门禁入账。
- 这是“后台采集、前台协调”的首期边界。若未来要求通知到达后立即后台写账，必须单独评审后台 Dart 引擎、数据库并发、功耗和 ROM 保活策略。

## 明确不包含

- 无障碍、主动截图、SMS、Root、Shizuku、Xposed 或私有支付 API；
- HyperOS 超级岛；
- 通知到达后在后台立即写 BeeCount 数据库；
- 未经验证来源的自动入账；
- 把通知原文发送给 AI。AI 文本兜底仍需独立 ADR 和开关。

## 验证门禁

- Manifest merge 后的 APK 必须包含且只包含 plugin 声明的 listener service。
- 覆盖默认关闭、拒绝授权、撤回授权、禁用来源、重复发布、更新、移除、进程重启、租约超时、损坏密文和 24 小时清理。
- 首要真机 Xiaomi 15 Pro / HyperOS 3.0.305.0 必须验证授权入口、后台接收、通知更新、进程终止恢复和电池策略。

## 回滚

从 Bundle 移除 Android plugin 依赖即可使最终 manifest 不再包含 listener。关闭总开关或通知来源开关必须停止新采集并清除未消费原始队列，不影响 BeeCount 原有截图记账和账本功能。
