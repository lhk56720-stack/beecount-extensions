import 'package:beecount_extension_api/beecount_extension_api.dart';

enum TransactionSemanticIssue {
  kindUnknown,
  directionConflict,
  preauthorizationNotFinal,
  relationshipMissing,
  relationshipEvidenceMissing,
  transferDestinationMissing,
  transferAccountsEqual,
}

final class TransactionSemanticResult {
  TransactionSemanticResult({
    required this.expectedDirection,
    required List<TransactionSemanticIssue> issues,
  }) : issues = List<TransactionSemanticIssue>.unmodifiable(issues);

  final AutomationDirection? expectedDirection;
  final List<TransactionSemanticIssue> issues;

  bool get isComplete => issues.isEmpty;
}

/// Central source of truth for payment meaning and accounting direction.
///
/// Parsers and AI may propose a kind and direction, but only this core rule
/// decides whether that combination is safe enough for automatic posting.
final class TransactionSemantics {
  const TransactionSemantics();

  TransactionSemanticResult evaluate(AutomationCandidate candidate) {
    final expectedDirection = directionFor(candidate.transactionKind);
    final issues = <TransactionSemanticIssue>[];

    if (candidate.transactionKind == AutomationTransactionKind.unknown) {
      issues.add(TransactionSemanticIssue.kindUnknown);
    }
    if (candidate.transactionKind ==
        AutomationTransactionKind.preauthorization) {
      issues.add(TransactionSemanticIssue.preauthorizationNotFinal);
    }
    if (expectedDirection != null &&
        candidate.direction != AutomationDirection.unknown &&
        candidate.direction != expectedDirection) {
      issues.add(TransactionSemanticIssue.directionConflict);
    }

    final needsRelationship = candidate.transactionKind ==
            AutomationTransactionKind.refund ||
        candidate.transactionKind ==
            AutomationTransactionKind.redPacketReturned;
    if (needsRelationship && candidate.relatedTransactionId == null) {
      issues.add(TransactionSemanticIssue.relationshipMissing);
    } else if (needsRelationship &&
        !candidate.hasEvidence(CandidateEvidenceField.relationship)) {
      issues.add(TransactionSemanticIssue.relationshipEvidenceMissing);
    }

    final isTransfer = candidate.transactionKind ==
            AutomationTransactionKind.transfer ||
        candidate.transactionKind ==
            AutomationTransactionKind.creditCardRepayment;
    if (isTransfer) {
      if (candidate.resolvedToAccountId == null) {
        issues.add(TransactionSemanticIssue.transferDestinationMissing);
      } else if (candidate.resolvedToAccountId ==
          candidate.resolvedAccountId) {
        issues.add(TransactionSemanticIssue.transferAccountsEqual);
      }
    }

    return TransactionSemanticResult(
      expectedDirection: expectedDirection,
      issues: issues,
    );
  }

  AutomationDirection? directionFor(AutomationTransactionKind kind) {
    return switch (kind) {
      AutomationTransactionKind.unknown => null,
      AutomationTransactionKind.purchase ||
        AutomationTransactionKind.redPacketSent ||
        AutomationTransactionKind.fee ||
        AutomationTransactionKind.preauthorization =>
        AutomationDirection.expense,
      AutomationTransactionKind.incomeReceipt ||
        AutomationTransactionKind.redPacketReceived =>
        AutomationDirection.income,
      AutomationTransactionKind.refund ||
        AutomationTransactionKind.redPacketReturned =>
        AutomationDirection.refund,
      AutomationTransactionKind.transfer ||
        AutomationTransactionKind.creditCardRepayment =>
        AutomationDirection.transfer,
    };
  }

  HostTransactionType? hostTypeFor(AutomationTransactionKind kind) {
    return switch (kind) {
      AutomationTransactionKind.unknown => null,
      AutomationTransactionKind.purchase ||
        AutomationTransactionKind.redPacketSent ||
        AutomationTransactionKind.fee ||
        AutomationTransactionKind.preauthorization =>
        HostTransactionType.expense,
      AutomationTransactionKind.incomeReceipt ||
        AutomationTransactionKind.refund ||
        AutomationTransactionKind.redPacketReceived ||
        AutomationTransactionKind.redPacketReturned =>
        HostTransactionType.income,
      AutomationTransactionKind.transfer ||
        AutomationTransactionKind.creditCardRepayment =>
        HostTransactionType.transfer,
    };
  }
}
