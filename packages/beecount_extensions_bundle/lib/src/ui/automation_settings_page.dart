import 'package:beecount_automation_android/beecount_automation_android.dart';
import 'package:flutter/material.dart';

import '../bootstrap/automation_bundle_controller.dart';
import '../model/automation_bundle_state.dart';
import 'automation_candidate_list_page.dart';

final class AutomationSettingsPage extends StatelessWidget {
  const AutomationSettingsPage({super.key, required this.controller});

  final AutomationBundleController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;
        final status = controller.collectionStatus;
        return Scaffold(
          appBar: AppBar(title: const Text('自动记账')),
          body: ListView(
            children: <Widget>[
              SwitchListTile.adaptive(
                title: const Text('启用自动记账'),
                subtitle: const Text('关闭后不再采集新的支付通知'),
                value: settings.automationEnabled,
                onChanged: (value) => _save(
                  controller,
                  settings.copyWith(automationEnabled: value),
                ),
              ),
              SwitchListTile.adaptive(
                title: const Text('读取支付通知'),
                subtitle: Text(
                  status?.accessGranted == true
                      ? '系统通知使用权已授权'
                      : '需要在系统设置中授权通知使用权',
                ),
                value: settings.notificationEnabled,
                onChanged: settings.automationEnabled
                    ? (value) => _save(
                          controller,
                          settings.copyWith(notificationEnabled: value),
                        )
                    : null,
              ),
              ListTile(
                title: const Text('授予通知使用权'),
                subtitle: const Text('Android 系统设置；不会申请无障碍、截图或短信权限'),
                trailing: const Icon(Icons.open_in_new),
                onTap: controller.openNotificationAccessSettings,
              ),
              SwitchListTile.adaptive(
                title: const Text('智能自动入账'),
                subtitle: const Text('仅对已真机验证的模板生效；其他账单进入待确认'),
                value: settings.autoPostEnabled,
                onChanged:
                    settings.automationEnabled && settings.notificationEnabled
                        ? (value) => _save(
                              controller,
                              settings.copyWith(autoPostEnabled: value),
                            )
                        : null,
              ),
              const Divider(),
              _ledgerSelector(controller: controller, settings: settings),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('通知来源'),
              ),
              for (final source in NotificationSourceRegistry.supported)
                _sourceSettings(
                  controller: controller,
                  settings: settings,
                  source: source,
                ),
              const Divider(),
              ListTile(
                title: Text('待确认账单（${controller.pendingCandidates.length}）'),
                subtitle: Text(
                  controller.processing ? '正在处理本地通知队列' : '点击检查、确认或忽略',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AutomationCandidateListPage(
                      controller: controller,
                    ),
                  ),
                ),
              ),
              if (controller.safeErrorCode != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('自动记账状态：${controller.safeErrorCode}'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _sourceSettings({
    required AutomationBundleController controller,
    required AutomationSettings settings,
    required NotificationSourceDescriptor source,
  }) {
    final enabled = settings.enabledSourceAppIds.contains(source.id);
    final accounts = controller.accounts.where((account) => account.isEnabled);
    final selectedAccountId = settings.sourceAccountIds[source.id];
    final hasSelectedAccount = accounts.any(
      (account) => account.id == selectedAccountId,
    );
    return Column(
      children: <Widget>[
        SwitchListTile.adaptive(
          title: Text(source.displayName),
          subtitle: Text(source.packageName),
          value: enabled,
          onChanged: settings.automationEnabled && settings.notificationEnabled
              ? (nextEnabled) {
                  final nextSources = <String>{...settings.enabledSourceAppIds};
                  if (nextEnabled) {
                    nextSources.add(source.id);
                  } else {
                    nextSources.remove(source.id);
                  }
                  _save(
                    controller,
                    settings.copyWith(enabledSourceAppIds: nextSources),
                  );
                }
              : null,
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 16, 8),
            child: DropdownButtonFormField<String>(
              value: hasSelectedAccount ? selectedAccountId : null,
              decoration: const InputDecoration(labelText: '扣款账户'),
              hint: const Text('未设置时进入待确认'),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('不自动指定'),
                ),
                ...accounts.map(
                  (account) => DropdownMenuItem<String>(
                    value: account.id,
                    child: Text(account.name),
                  ),
                ),
              ],
              onChanged: (accountId) {
                final mappings = <String, String>{...settings.sourceAccountIds};
                if (accountId == null) {
                  mappings.remove(source.id);
                } else {
                  mappings[source.id] = accountId;
                }
                _save(
                  controller,
                  settings.copyWith(sourceAccountIds: mappings),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _ledgerSelector({
    required AutomationBundleController controller,
    required AutomationSettings settings,
  }) {
    final writable = controller.ledgers.where((ledger) => ledger.isWritable);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: settings.targetLedgerId,
        decoration: const InputDecoration(labelText: '自动记账账本'),
        items: <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(
            value: null,
            child: Text('跟随当前账本'),
          ),
          ...writable.map(
            (ledger) => DropdownMenuItem<String>(
              value: ledger.id,
              child: Text(ledger.name),
            ),
          ),
        ],
        onChanged: (value) => _save(
          controller,
          settings.copyWith(
            targetLedgerId: value,
            clearTargetLedger: value == null,
          ),
        ),
      ),
    );
  }

  Future<void> _save(
    AutomationBundleController controller,
    AutomationSettings settings,
  ) =>
      controller.updateSettings(settings);
}
