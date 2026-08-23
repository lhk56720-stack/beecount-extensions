import 'package:beecount_automation_core/beecount_automation_core.dart';
import 'package:test/test.dart';

import 'test_candidate.dart';

void main() {
  const engine = AccountMappingEngine();

  test('exact opaque token mapping wins over source default', () {
    final candidate = testCandidate(
      accountId: null,
      accountHintToken: 'hmac-sha256:card-token',
    );
    final decision = engine.resolve(
      candidate,
      const <AccountMappingRule>[
        AccountMappingRule(
          id: 'default-rule',
          ledgerId: 'ledger-1',
          sourceAppId: 'wechat',
          accountId: 'account-default',
          enabled: true,
          isSourceDefault: true,
        ),
        AccountMappingRule(
          id: 'token-rule',
          ledgerId: 'ledger-1',
          sourceAppId: 'wechat',
          accountId: 'account-card',
          accountHintToken: 'hmac-sha256:card-token',
          enabled: true,
          isSourceDefault: false,
        ),
      ],
    );

    expect(decision.kind, AccountMappingMatchKind.exactToken);
    expect(decision.accountId, 'account-card');
  });

  test('ambiguous source defaults do not guess an account', () {
    final candidate = testCandidate(accountId: null);
    final decision = engine.resolve(
      candidate,
      const <AccountMappingRule>[
        AccountMappingRule(
          id: 'default-a',
          ledgerId: 'ledger-1',
          sourceAppId: 'wechat',
          accountId: 'account-a',
          enabled: true,
          isSourceDefault: true,
        ),
        AccountMappingRule(
          id: 'default-b',
          ledgerId: 'ledger-1',
          sourceAppId: 'wechat',
          accountId: 'account-b',
          enabled: true,
          isSourceDefault: true,
        ),
      ],
    );

    expect(decision.kind, AccountMappingMatchKind.none);
    expect(decision.accountId, isNull);
  });
}
