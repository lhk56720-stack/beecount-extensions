import 'package:beecount_extension_api/beecount_extension_api.dart';

import '../dedup/deduplication_engine.dart';
import '../rules/transaction_semantics.dart';

enum PostingDecisionKind {
  autoPost,
  pending,
  ignored,
  duplicate,
  updateExisting,
}

enum PostingBlockReason {
  automationDisabled,
  sourceDisabled,
  candidateStateNotEligible,
  ledgerMissing,
  amountMissing,
  currencyMissing,
  directionUnknown,
  currentSourceUnavailable,
  transactionKindUnknown,
  transactionKindEvidenceMissing,
  transactionDirectionConflict,
  preauthorizationNotFinal,
  amountEvidenceMissing,
  directionEvidenceMissing,
  occurredAtEvidenceMissing,
  accountMissing,
  transferDestinationMissing,
  transferAccountsEqual,
  refundRelationshipMissing,
  relationshipEvidenceMissing,
  possibleDuplicate,
  confirmedDuplicate,
  sourceEventUpdate,
}

final class PostingPolicy {
  PostingPolicy({
    required this.automationEnabled,
    required Set<String> enabledSourceAppIds,
    required Set<AutomationSourceCapability> enabledCapabilities,
  })  : enabledSourceAppIds = Set<String>.unmodifiable(enabledSourceAppIds),
        enabledCapabilities =
            Set<AutomationSourceCapability>.unmodifiable(enabledCapabilities);

  final bool automationEnabled;
  final Set<String> enabledSourceAppIds;
  final Set<AutomationSourceCapability> enabledCapabilities;
}

final class PostingDecision {
  PostingDecision({
    required this.kind,
    required List<PostingBlockReason> reasons,
    this.command,
  }) : reasons = List<PostingBlockReason>.unmodifiable(reasons);

  final PostingDecisionKind kind;
  final List<PostingBlockReason> reasons;
  final PostingCommand? command;
}

final class PostingDecisionEngine {
  const PostingDecisionEngine({
    this.transactionSemantics = const TransactionSemantics(),
  });

  final TransactionSemantics transactionSemantics;

  PostingDecision decide({
    required AutomationCandidate candidate,
    required DeduplicationDecision deduplication,
    required PostingPolicy policy,
  }) {
    if (!policy.automationEnabled) {
      return _blocked(
        PostingDecisionKind.ignored,
        PostingBlockReason.automationDisabled,
      );
    }

    final enabledSources = candidate.sources.where(
      (source) =>
          policy.enabledSourceAppIds.contains(source.sourceAppId) &&
          policy.enabledCapabilities.contains(source.capability),
    );
    if (enabledSources.isEmpty) {
      return _blocked(
        PostingDecisionKind.ignored,
        PostingBlockReason.sourceDisabled,
      );
    }
    final activeSources = enabledSources.where(
      (source) =>
          source.isCurrent &&
          source.lifecycle != PlatformEventLifecycle.removed,
    );
    final activeSourceIdentityKeys =
        activeSources.map((source) => source.identityKey).toSet();

    if (deduplication.kind == DeduplicationKind.update) {
      return _blocked(
        PostingDecisionKind.updateExisting,
        PostingBlockReason.sourceEventUpdate,
      );
    }
    if (deduplication.kind == DeduplicationKind.duplicate) {
      return _blocked(
        PostingDecisionKind.duplicate,
        PostingBlockReason.confirmedDuplicate,
      );
    }

    final reasons = <PostingBlockReason>[];
    if (candidate.state != AutomationCandidateState.detected &&
        candidate.state != AutomationCandidateState.pending) {
      reasons.add(PostingBlockReason.candidateStateNotEligible);
    }
    if (candidate.targetLedgerId == null) {
      reasons.add(PostingBlockReason.ledgerMissing);
    }
    if (candidate.amountMinor == null) {
      reasons.add(PostingBlockReason.amountMissing);
    }
    if (candidate.currency == null) {
      reasons.add(PostingBlockReason.currencyMissing);
    }
    if (candidate.direction == AutomationDirection.unknown) {
      reasons.add(PostingBlockReason.directionUnknown);
    }
    if (activeSources.isEmpty) {
      reasons.add(PostingBlockReason.currentSourceUnavailable);
    }
    if (!candidate.hasEvidence(
      CandidateEvidenceField.transactionKind,
      sourceIdentityKeys: activeSourceIdentityKeys,
    )) {
      reasons.add(PostingBlockReason.transactionKindEvidenceMissing);
    }
    if (!candidate.hasEvidence(
      CandidateEvidenceField.amount,
      sourceIdentityKeys: activeSourceIdentityKeys,
    )) {
      reasons.add(PostingBlockReason.amountEvidenceMissing);
    }
    if (!candidate.hasEvidence(
      CandidateEvidenceField.direction,
      sourceIdentityKeys: activeSourceIdentityKeys,
    )) {
      reasons.add(PostingBlockReason.directionEvidenceMissing);
    }
    if (!candidate.hasEvidence(
      CandidateEvidenceField.occurredAt,
      sourceIdentityKeys: activeSourceIdentityKeys,
    )) {
      reasons.add(PostingBlockReason.occurredAtEvidenceMissing);
    }
    if (candidate.resolvedAccountId == null) {
      reasons.add(PostingBlockReason.accountMissing);
    }

    final semanticResult = transactionSemantics.evaluate(candidate);
    for (final issue in semanticResult.issues) {
      final reason = _postingReasonFor(issue);
      if (!reasons.contains(reason)) reasons.add(reason);
    }
    final needsRelationshipEvidence = candidate.transactionKind ==
            AutomationTransactionKind.refund ||
        candidate.transactionKind ==
            AutomationTransactionKind.redPacketReturned;
    if (needsRelationshipEvidence &&
        !candidate.hasEvidence(
          CandidateEvidenceField.relationship,
          sourceIdentityKeys: activeSourceIdentityKeys,
        ) &&
        !reasons.contains(PostingBlockReason.relationshipEvidenceMissing)) {
      reasons.add(PostingBlockReason.relationshipEvidenceMissing);
    }
    if (deduplication.kind == DeduplicationKind.possibleDuplicate) {
      reasons.add(PostingBlockReason.possibleDuplicate);
    }

    if (reasons.isNotEmpty) {
      return PostingDecision(
        kind: PostingDecisionKind.pending,
        reasons: reasons,
      );
    }

    return PostingDecision(
      kind: PostingDecisionKind.autoPost,
      reasons: const <PostingBlockReason>[],
      command: PostingCommand(
        candidateId: candidate.id,
        idempotencyKey:
            'automation:${AutomationCandidate.currentSchemaVersion}:${candidate.id}',
        ledgerId: candidate.targetLedgerId!,
        occurredAt: candidate.occurredAt,
        amountMinor: candidate.amountMinor!,
        currency: candidate.currency!,
        hostType:
            transactionSemantics.hostTypeFor(candidate.transactionKind)!,
        direction: candidate.direction,
        transactionKind: candidate.transactionKind,
        accountId: candidate.resolvedAccountId!,
        toAccountId: candidate.resolvedToAccountId,
        categoryId: candidate.resolvedCategoryId,
        relatedTransactionId: candidate.relatedTransactionId,
        merchant: candidate.merchant,
        note: candidate.note,
      ),
    );
  }

  PostingDecision _blocked(
    PostingDecisionKind kind,
    PostingBlockReason reason,
  ) {
    return PostingDecision(
      kind: kind,
      reasons: <PostingBlockReason>[reason],
    );
  }

  PostingBlockReason _postingReasonFor(TransactionSemanticIssue issue) {
    return switch (issue) {
      TransactionSemanticIssue.kindUnknown =>
        PostingBlockReason.transactionKindUnknown,
      TransactionSemanticIssue.directionConflict =>
        PostingBlockReason.transactionDirectionConflict,
      TransactionSemanticIssue.preauthorizationNotFinal =>
        PostingBlockReason.preauthorizationNotFinal,
      TransactionSemanticIssue.relationshipMissing =>
        PostingBlockReason.refundRelationshipMissing,
      TransactionSemanticIssue.relationshipEvidenceMissing =>
        PostingBlockReason.relationshipEvidenceMissing,
      TransactionSemanticIssue.transferDestinationMissing =>
        PostingBlockReason.transferDestinationMissing,
      TransactionSemanticIssue.transferAccountsEqual =>
        PostingBlockReason.transferAccountsEqual,
    };
  }
}
