import 'package:beecount_automation_core/beecount_automation_core.dart';
import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:test/test.dart';

import 'test_candidate.dart';

void main() {
  const engine = DeduplicationEngine();

  test('same source event is treated as an update', () {
    final existing = testCandidate(id: 'existing');
    final incoming = testCandidate(id: 'incoming');

    final result = engine.evaluate(
      incoming,
      <DeduplicationFact>[DeduplicationFact.fromCandidate(existing)],
    );

    expect(result.kind, DeduplicationKind.update);
    expect(result.matchedId, 'existing');
  });

  test('stable transaction hash confirms a duplicate', () {
    final existing = testCandidate(
      id: 'existing',
      eventId: 'event-a',
      stableTransactionIdHash: 'hmac-sha256:stable-id',
    );
    final incoming = testCandidate(
      id: 'incoming',
      eventId: 'event-b',
      stableTransactionIdHash: 'hmac-sha256:stable-id',
    );

    final result = engine.evaluate(
      incoming,
      <DeduplicationFact>[DeduplicationFact.fromCandidate(existing)],
    );

    expect(result.kind, DeduplicationKind.duplicate);
  });

  test('same amount and time alone are not enough to deduplicate', () {
    final existing = HostTransactionSummary(
      id: 'transaction-1',
      ledgerId: 'ledger-1',
      occurredAt: DateTime.utc(2026, 8, 23, 10),
      amountMinor: 1280,
      currency: 'CNY',
      hostType: HostTransactionType.expense,
      direction: AutomationDirection.expense,
    );

    final result = engine.evaluate(
      testCandidate(merchant: null, accountId: null),
      <DeduplicationFact>[
        DeduplicationFact.fromHostTransaction(existing),
      ],
    );

    expect(result.kind, DeduplicationKind.unique);
  });

  test('cross-source account match remains pending as possible duplicate', () {
    final existing = testCandidate(
      id: 'existing',
      eventId: 'bank-event',
      sourceAppId: 'bank-example',
      merchant: '银行扣款',
    );
    final incoming = testCandidate(
      id: 'incoming',
      eventId: 'wechat-event',
      sourceAppId: 'wechat',
      merchant: '示例商户',
    );

    final result = engine.evaluate(
      incoming,
      <DeduplicationFact>[DeduplicationFact.fromCandidate(existing)],
    );

    expect(result.kind, DeduplicationKind.possibleDuplicate);
  });
}
