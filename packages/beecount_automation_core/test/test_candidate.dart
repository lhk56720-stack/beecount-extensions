import 'package:beecount_extension_api/beecount_extension_api.dart';

AutomationCandidate testCandidate({
  String id = 'candidate-1',
  String eventId = 'event-1',
  String sourceAppId = 'wechat',
  AutomationSourceCapability capability =
      AutomationSourceCapability.notification,
  PlatformEventLifecycle lifecycle = PlatformEventLifecycle.posted,
  bool isCurrent = true,
  DateTime? occurredAt,
  int? amountMinor = 1280,
  String? currency = 'CNY',
  AutomationDirection direction = AutomationDirection.expense,
  AutomationTransactionKind transactionKind =
      AutomationTransactionKind.purchase,
  String? merchant = '示例商户',
  String? ledgerId = 'ledger-1',
  String? accountHintToken,
  String? accountId = 'account-1',
  String? toAccountId,
  String? relatedTransactionId,
  String? stableTransactionIdHash,
  double? parserConfidence,
  List<SourceEventReference> additionalSources = const <SourceEventReference>[],
  AutomationCandidateState state = AutomationCandidateState.detected,
  Set<CandidateEvidenceField> evidenceFields = const <CandidateEvidenceField>{
    CandidateEvidenceField.amount,
    CandidateEvidenceField.direction,
    CandidateEvidenceField.transactionKind,
    CandidateEvidenceField.occurredAt,
  },
}) {
  final time = occurredAt ?? DateTime.utc(2026, 8, 23, 10);
  return AutomationCandidate(
    id: id,
    targetLedgerId: ledgerId,
    createdAt: time,
    updatedAt: time,
    occurredAt: time,
    amountMinor: amountMinor,
    currency: currency,
    direction: direction,
    transactionKind: transactionKind,
    merchant: merchant,
    accountHintToken: accountHintToken,
    resolvedAccountId: accountId,
    resolvedToAccountId: toAccountId,
    relatedTransactionId: relatedTransactionId,
    stableTransactionIdHash: stableTransactionIdHash,
    parserConfidence: parserConfidence,
    sources: <SourceEventReference>[
      SourceEventReference(
        capability: capability,
        sourceAppId: sourceAppId,
        eventIdHash: 'hmac-sha256:$eventId',
        lifecycle: lifecycle,
        isCurrent: isCurrent,
        observedAt: time,
        parserVersion: 1,
      ),
      ...additionalSources,
    ],
    evidence: evidenceFields
        .map(
          (field) => CandidateEvidence(
            field: field,
            sourceIdentityKey:
                '${capability.name}:$sourceAppId:hmac-sha256:$eventId',
          ),
        )
        .toList(growable: false),
    state: state,
    parserVersion: 1,
  );
}
