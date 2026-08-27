import 'package:beecount_automation_core/beecount_automation_core.dart';
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
                            onPressed: () => _confirm(
                              context,
                              controller,
                              candidate.id,
                            ),
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

  Future<void> _confirm(
    BuildContext context,
    AutomationBundleController controller,
    String candidateId,
  ) async {
    CandidateConfirmationResult result;
    try {
      result = await controller.confirmCandidate(candidateId);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('确认入账失败，请稍后重试并查看诊断记录')),
      );
      return;
    }
    if (!context.mounted) return;
    final message =
        result.succeeded ? '已确认入账' : _confirmationFailureMessage(result);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _confirmationFailureMessage(CandidateConfirmationResult result) {
    final reasons = result.blockReasons.toSet();
    if (reasons.contains(PostingBlockReason.accountMissing)) {
      return '无法入账：请先为该通知来源选择扣款账户';
    }
    if (reasons.contains(PostingBlockReason.ledgerMissing)) {
      return '无法入账：当前没有可写账本';
    }
    if (reasons.contains(PostingBlockReason.amountMissing) ||
        reasons.contains(PostingBlockReason.amountEvidenceMissing)) {
      return '无法入账：通知中没有可确认的金额';
    }
    if (reasons.contains(PostingBlockReason.directionUnknown) ||
        reasons.contains(PostingBlockReason.transactionKindUnknown) ||
        reasons.contains(PostingBlockReason.transactionDirectionConflict)) {
      return '无法入账：交易方向或类型仍需确认';
    }
    if (reasons.contains(PostingBlockReason.possibleDuplicate) ||
        reasons.contains(PostingBlockReason.confirmedDuplicate)) {
      return '无法入账：检测到可能重复的交易';
    }
    if (reasons.contains(PostingBlockReason.refundRelationshipMissing) ||
        reasons.contains(PostingBlockReason.relationshipEvidenceMissing)) {
      return '无法入账：退款或红包退回缺少原交易关联';
    }
    if (reasons.contains(PostingBlockReason.transferDestinationMissing) ||
        reasons.contains(PostingBlockReason.transferAccountsEqual)) {
      return '无法入账：转账需要两个不同账户';
    }
    return '确认入账失败，请在自动记账诊断中查看原因';
  }
}
