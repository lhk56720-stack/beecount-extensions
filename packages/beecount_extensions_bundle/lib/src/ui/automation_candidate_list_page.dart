import 'package:flutter/material.dart';

import '../bootstrap/automation_bundle_controller.dart';

final class AutomationCandidateListPage extends StatelessWidget {
  const AutomationCandidateListPage({super.key, required this.controller});

  final AutomationBundleController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final candidates = controller.pendingCandidates;
        return Scaffold(
          appBar: AppBar(title: const Text('待确认账单')),
          body: candidates.isEmpty
              ? const Center(child: Text('暂无待确认账单'))
              : ListView.builder(
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final candidate = candidates[index];
                    final amount = candidate.amountMinor == null
                        ? '金额待确认'
                        : '¥${(candidate.amountMinor! / 100).toStringAsFixed(2)}';
                    return ListTile(
                      title: Text(candidate.merchant ?? '支付通知待确认'),
                      subtitle: Text(
                        '${candidate.transactionKind.name} · ${candidate.state.name}',
                      ),
                      leading: Text(amount),
                      trailing: Wrap(
                        spacing: 4,
                        children: <Widget>[
                          IconButton(
                            tooltip: '忽略',
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                controller.ignoreCandidate(candidate.id),
                          ),
                          IconButton(
                            tooltip: '确认入账',
                            icon: const Icon(Icons.check),
                            onPressed: () =>
                                controller.confirmCandidate(candidate.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
