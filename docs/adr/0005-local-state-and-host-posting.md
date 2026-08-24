# ADR-0005：候选状态与宿主入账幂等边界

- 状态：Accepted
- 日期：2026-08-24
- 决策者：项目所有者

## 背景

通知原文成功解析后必须立即从短期恢复队列销毁，但待确认候选、来源开关、账户映射和入账回执仍需跨进程保存。扩展又不能把候选写入 BeeCount Drift 数据库或云同步。自动入账还必须保证同一候选重放不会重复创建交易。

## 决策

- Android plugin 在 `noBackupFilesDir` 保存一个经过 Android Keystore AES-256-GCM 加密的 Bundle 状态快照；Flutter 只读写结构化候选、设置、映射和安全回执，不保存通知原文。
- 状态快照不进入 Android Backup、BeeCount 云同步、账单导出或日志。单个快照限制为 1 MiB，候选数量由 Bundle 限制为 500 条并按保留策略清理。
- Bundle 是队列消费、解析、候选持久化、映射、去重和 Core 入账门禁的唯一协调者。Android plugin 不理解交易语义，BeeCount host 不读取通知原文。
- 宿主 `TransactionPort` 使用入账命令的 `idempotencyKey` 派生确定性 UUID，作为 BeeCount 交易 `syncId`。写入前按该 UUID 查询：完全一致返回 `alreadyApplied`，不一致返回 `idempotencyConflict`；同一进程内串行化检查和写入。
- 候选先持久化为 pending/posting 状态，再调用宿主端口，最后保存正式交易 ID。进程在宿主写入后崩溃时，重放会通过确定性 `syncId` 找回原交易，不创建第二条账。
- 禁用自动记账只停止采集和自动处理，不删除已生成的正式交易。清除候选必须由用户显式操作。

## 不包含

- 不修改 BeeCount Drift schema，不把扩展候选塞进交易备注；
- 不把候选或映射同步到云端；
- 不允许 AI、Android platform 或 UI 绕过 Core 直接写正式交易；
- 不承诺多设备对同一通知协同消费，通知能力是设备本地能力。

## 验证

- 覆盖状态加密读写、损坏密文安全清空、大小上限、进程重启和禁用后保留候选；
- 覆盖相同幂等键重放、不同命令复用幂等键、宿主写入后崩溃恢复和并发调用；
- 检查状态文件位于 `noBackupFilesDir`，日志与云同步中不含候选或原始通知。
