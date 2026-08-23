import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:test/test.dart';

void main() {
  test('candidate round-trips without raw platform text', () {
    final candidate = AutomationCandidate(
      id: 'candidate-1',
      targetLedgerId: 'ledger-1',
      createdAt: DateTime.utc(2026, 8, 23, 10),
      updatedAt: DateTime.utc(2026, 8, 23, 10),
      occurredAt: DateTime.utc(2026, 8, 23, 9, 59),
      amountMinor: 1280,
      currency: 'CNY',
      direction: AutomationDirection.expense,
      transactionKind: AutomationTransactionKind.purchase,
      merchant: '示例商户',
      resolvedAccountId: 'account-1',
      sources: <SourceEventReference>[
        SourceEventReference(
          capability: AutomationSourceCapability.notification,
          sourceAppId: 'wechat',
          packageName: 'com.tencent.mm',
          eventIdHash: 'hmac-sha256:event-1',
          lifecycle: PlatformEventLifecycle.posted,
          isCurrent: true,
          observedAt: DateTime.utc(2026, 8, 23, 9, 59),
          parserVersion: 1,
        ),
      ],
      evidence: const <CandidateEvidence>[
        CandidateEvidence(
          field: CandidateEvidenceField.amount,
          sourceIdentityKey: 'notification:wechat:hmac-sha256:event-1',
        ),
      ],
      state: AutomationCandidateState.detected,
      parserVersion: 1,
    );

    final json = candidate.toJson();
    final restored = AutomationCandidate.fromJson(json);

    expect(restored.id, candidate.id);
    expect(restored.amountMinor, 1280);
    expect(restored.transactionKind, AutomationTransactionKind.purchase);
    expect(
      restored.sources.single.identityKey,
      'notification:wechat:hmac-sha256:event-1',
    );
    expect(json.containsKey('rawText'), isFalse);
    expect(json.containsKey('notificationText'), isFalse);

    final invalidEvidenceJson = Map<String, Object?>.from(json)
      ..['evidence'] = <Map<String, Object?>>[
        <String, Object?>{
          'field': 'amount',
          'sourceIdentityKey':
              'notification:alipay:hmac-sha256:unrelated-event',
          'start': null,
          'end': null,
        },
      ];
    expect(
      () => AutomationCandidate.fromJson(invalidEvidenceJson),
      throwsArgumentError,
    );

    final sourceTemplate = Map<String, Object?>.from(
      (json['sources'] as List).single as Map,
    );
    final oldSource = Map<String, Object?>.from(sourceTemplate)
      ..['eventIdHash'] = 'hmac-sha256:event-old'
      ..['isCurrent'] = false;
    final currentSource = Map<String, Object?>.from(sourceTemplate)
      ..['eventIdHash'] = 'hmac-sha256:event-current'
      ..['supersedesEventIdHash'] = 'hmac-sha256:event-old'
      ..['lifecycle'] = 'updated'
      ..['isCurrent'] = true;
    final historyJson = Map<String, Object?>.from(json)
      ..['sources'] = <Map<String, Object?>>[oldSource, currentSource]
      ..['evidence'] = <Map<String, Object?>>[
        <String, Object?>{
          'field': 'amount',
          'sourceIdentityKey': 'notification:wechat:hmac-sha256:event-current',
          'start': null,
          'end': null,
        },
      ];
    expect(
      AutomationCandidate.fromJson(historyJson)
          .sources
          .where((source) => source.isCurrent)
          .single
          .eventIdHash,
      'hmac-sha256:event-current',
    );
  });

  test('unknown schema version is rejected', () {
    expect(
      () => AutomationCandidate.fromJson(<String, Object?>{
        'schemaVersion': 99,
      }),
      throwsFormatException,
    );
  });
}
