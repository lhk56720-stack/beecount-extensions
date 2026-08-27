import 'package:flutter/material.dart';

import '../bootstrap/automation_bundle_controller.dart';

final class AutomationDiagnosticsPage extends StatelessWidget {
  const AutomationDiagnosticsPage({
    super.key,
    required this.controller,
  });

  final AutomationBundleController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final diagnostics = controller.diagnostics;
        return Scaffold(
          appBar: AppBar(
            title: const Text('自动记账诊断'),
            actions: <Widget>[
              TextButton(
                onPressed: diagnostics.isEmpty
                    ? null
                    : () => _clear(context, controller),
                child: const Text('清除'),
              ),
            ],
          ),
          body: diagnostics.isEmpty
              ? const Center(child: Text('暂无诊断记录'))
              : ListView.separated(
                  itemCount: diagnostics.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final event = diagnostics[index];
                    final localTime = event.occurredAt.toLocal();
                    final source = event.sourceAppId == null
                        ? ''
                        : ' · ${event.sourceAppId}';
                    return ListTile(
                      dense: true,
                      title: Text(_displayCode(event.code)),
                      subtitle: Text('${_formatTime(localTime)}$source'),
                    );
                  },
                ),
          bottomNavigationBar: const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '仅保留最近 200 条本地结构化事件；不记录通知原文、金额、商户、账号或通知标识。',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _clear(
    BuildContext context,
    AutomationBundleController controller,
  ) async {
    await controller.clearDiagnostics();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('诊断记录已清除')),
    );
  }

  String _displayCode(String code) {
    if (code == 'automation.initialized') return '自动记账服务已初始化';
    if (code == 'automation.foreground_refresh') return '应用回到前台并刷新';
    if (code == 'settings.updated') return '自动记账设置已更新';
    if (code == 'queue.processing_started') return '开始处理通知队列';
    if (code == 'queue.lease_received') return '读取到待处理通知事件';
    if (code == 'queue.processing_completed') return '通知队列处理完成';
    if (code == 'queue.processing_failed') return '通知队列处理失败';
    if (code == 'candidate.detected') return '已生成完整候选账单';
    if (code == 'candidate.pending') return '已生成待确认候选账单';
    if (code == 'confirmation.posted') return '候选账单已确认入账';
    if (code == 'confirmation.post_failed') return '宿主拒绝写入账单';
    if (code.startsWith('confirmation.blocked.')) {
      return '确认被安全门禁阻止：${code.substring('confirmation.blocked.'.length)}';
    }
    return code;
  }

  String _formatTime(DateTime time) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${twoDigits(time.month)}-${twoDigits(time.day)} '
        '${twoDigits(time.hour)}:${twoDigits(time.minute)}:${twoDigits(time.second)}';
  }
}
