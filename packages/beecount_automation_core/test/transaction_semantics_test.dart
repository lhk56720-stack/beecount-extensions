import 'package:beecount_automation_core/beecount_automation_core.dart';
import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:test/test.dart';

import 'test_candidate.dart';

void main() {
  const semantics = TransactionSemantics();

  final directionCases = <(AutomationTransactionKind, AutomationDirection)>[
    (AutomationTransactionKind.purchase, AutomationDirection.expense),
    (AutomationTransactionKind.fee, AutomationDirection.expense),
    (AutomationTransactionKind.redPacketSent, AutomationDirection.expense),
    (AutomationTransactionKind.incomeReceipt, AutomationDirection.income),
    (AutomationTransactionKind.redPacketReceived, AutomationDirection.income),
    (AutomationTransactionKind.refund, AutomationDirection.refund),
    (AutomationTransactionKind.redPacketReturned, AutomationDirection.refund),
    (AutomationTransactionKind.transfer, AutomationDirection.transfer),
    (
      AutomationTransactionKind.creditCardRepayment,
      AutomationDirection.transfer,
    ),
  ];

  for (final (kind, direction) in directionCases) {
    test('$kind maps to $direction', () {
      expect(semantics.directionFor(kind), direction);
    });
  }

  test('refund must retain a relationship to its original transaction', () {
    final result = semantics.evaluate(
      testCandidate(
        direction: AutomationDirection.refund,
        transactionKind: AutomationTransactionKind.refund,
      ),
    );

    expect(
      result.issues,
      contains(TransactionSemanticIssue.relationshipMissing),
    );
  });

  test('refund is stored as a new host income transaction', () {
    expect(
      semantics.hostTypeFor(AutomationTransactionKind.refund),
      HostTransactionType.income,
    );
  });

  test('refund relationship must be evidence-backed', () {
    final result = semantics.evaluate(
      testCandidate(
        direction: AutomationDirection.refund,
        transactionKind: AutomationTransactionKind.refund,
        relatedTransactionId: 'transaction-1',
      ),
    );

    expect(
      result.issues,
      contains(TransactionSemanticIssue.relationshipEvidenceMissing),
    );
  });

  test('credit-card repayment requires two distinct accounts', () {
    final result = semantics.evaluate(
      testCandidate(
        direction: AutomationDirection.transfer,
        transactionKind: AutomationTransactionKind.creditCardRepayment,
        toAccountId: 'account-1',
      ),
    );

    expect(
      result.issues,
      contains(TransactionSemanticIssue.transferAccountsEqual),
    );
  });

  test('preauthorization is never a final auto-postable transaction', () {
    final result = semantics.evaluate(
      testCandidate(
        transactionKind: AutomationTransactionKind.preauthorization,
      ),
    );

    expect(
      result.issues,
      contains(TransactionSemanticIssue.preauthorizationNotFinal),
    );
  });
}
