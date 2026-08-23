import 'automation_candidate.dart';

enum HostTransactionType {
  expense,
  income,
  transfer,
}

final class LedgerSummary {
  const LedgerSummary({
    required this.id,
    required this.name,
    required this.baseCurrency,
    required this.isWritable,
  });

  final String id;
  final String name;
  final String baseCurrency;
  final bool isWritable;
}

final class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.name,
    required this.currency,
    required this.isEnabled,
    this.maskedIdentifier,
  });

  final String id;
  final String name;
  final String currency;
  final bool isEnabled;
  final String? maskedIdentifier;
}

final class CategorySummary {
  const CategorySummary({
    required this.id,
    required this.name,
    required this.direction,
    required this.isUsable,
  });

  final String id;
  final String name;
  final AutomationDirection direction;
  final bool isUsable;
}

final class HostTransactionSummary {
  const HostTransactionSummary({
    required this.id,
    required this.ledgerId,
    required this.occurredAt,
    required this.amountMinor,
    required this.currency,
    required this.hostType,
    required this.direction,
    this.accountId,
    this.toAccountId,
    this.merchant,
    this.automationCandidateId,
    this.stableTransactionIdHash,
  });

  final String id;
  final String ledgerId;
  final DateTime occurredAt;
  final int amountMinor;
  final String currency;
  final HostTransactionType hostType;
  final AutomationDirection direction;
  final String? accountId;
  final String? toAccountId;
  final String? merchant;
  final String? automationCandidateId;
  final String? stableTransactionIdHash;
}

final class PostingCommand {
  const PostingCommand({
    required this.candidateId,
    required this.idempotencyKey,
    required this.ledgerId,
    required this.occurredAt,
    required this.amountMinor,
    required this.currency,
    required this.hostType,
    required this.direction,
    required this.transactionKind,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.relatedTransactionId,
    this.merchant,
    this.note,
  });

  final String candidateId;
  final String idempotencyKey;
  final String ledgerId;
  final DateTime occurredAt;
  final int amountMinor;
  final String currency;
  final HostTransactionType hostType;
  final AutomationDirection direction;
  final AutomationTransactionKind transactionKind;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? relatedTransactionId;
  final String? merchant;
  final String? note;
}

enum PostingResultStatus {
  created,
  alreadyApplied,
  idempotencyConflict,
  rejected,
}

final class PostingResult {
  const PostingResult({
    required this.status,
    this.transactionId,
    this.safeErrorCode,
  });

  final PostingResultStatus status;
  final String? transactionId;
  final String? safeErrorCode;
}
