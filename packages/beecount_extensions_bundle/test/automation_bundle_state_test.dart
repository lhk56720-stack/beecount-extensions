import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:beecount_extensions_bundle/beecount_extensions_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundle state round-trips structured candidates and local settings', () {
    final time = DateTime.utc(2026, 8, 24, 12);
    final candidate = AutomationCandidate(
      id: 'notification:wechat:hmac-sha256_event',
      targetLedgerId: 'ledger-1',
      createdAt: time,
      updatedAt: time,
      occurredAt: time,
      amountMinor: 1280,
      currency: 'CNY',
      direction: AutomationDirection.expense,
      transactionKind: AutomationTransactionKind.purchase,
      merchant: '示例商户',
      sources: <SourceEventReference>[
        SourceEventReference(
          capability: AutomationSourceCapability.notification,
          sourceAppId: 'wechat',
          eventIdHash: 'hmac-sha256:event',
          lifecycle: PlatformEventLifecycle.posted,
          isCurrent: true,
          observedAt: time,
          parserVersion: 1,
        ),
      ],
      evidence: const <CandidateEvidence>[
        CandidateEvidence(
          field: CandidateEvidenceField.amount,
          sourceIdentityKey: 'notification:wechat:hmac-sha256:event',
        ),
      ],
      state: AutomationCandidateState.pending,
      parserVersion: 1,
    );
    final original = AutomationBundleState(
      settings: AutomationSettings(
        automationEnabled: true,
        notificationEnabled: true,
        autoPostEnabled: false,
        enabledSourceAppIds: const <String>{'wechat'},
        targetLedgerId: 'ledger-1',
        sourceAccountIds: const <String, String>{'wechat': 'account-1'},
      ),
      candidates: <AutomationCandidate>[candidate],
      postedTransactionIds: const <String, String>{'candidate-1': 'tx-1'},
      diagnostics: <AutomationDiagnosticEvent>[
        AutomationDiagnosticEvent(
          occurredAt: time,
          code: 'confirmation.blocked.account_missing',
          sourceAppId: 'wechat',
        ),
      ],
    );

    final restored = AutomationBundleState.fromJson(original.toJson());

    expect(restored.settings.enabledSourceAppIds, <String>{'wechat'});
    expect(restored.settings.sourceAccountIds['wechat'], 'account-1');
    expect(restored.candidates.single.id, candidate.id);
    expect(restored.candidates.single.amountMinor, 1280);
    expect(restored.postedTransactionIds['candidate-1'], 'tx-1');
    expect(restored.diagnostics.single.sourceAppId, 'wechat');
    expect(
      restored.diagnostics.single.code,
      'confirmation.blocked.account_missing',
    );
    expect(restored.toJson().toString(), isNot(contains('platform-event-1')));
  });
}
