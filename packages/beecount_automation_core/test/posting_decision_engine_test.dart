import 'package:beecount_automation_core/beecount_automation_core.dart';
import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:test/test.dart';

import 'test_candidate.dart';

void main() {
  const engine = PostingDecisionEngine();

  PostingPolicy enabledPolicy() => PostingPolicy(
        automationEnabled: true,
        enabledSourceAppIds: const <String>{'wechat'},
        enabledCapabilities: const <AutomationSourceCapability>{
          AutomationSourceCapability.notification,
        },
      );

  test('complete evidence-backed expense can auto-post', () {
    final decision = engine.decide(
      candidate: testCandidate(),
      deduplication: DeduplicationDecision.unique,
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.autoPost);
    expect(decision.command?.amountMinor, 1280);
    expect(decision.command?.idempotencyKey, 'automation:1:candidate-1');
  });

  test('parser confidence does not replace missing amount evidence', () {
    final candidate = testCandidate(
      evidenceFields: const <CandidateEvidenceField>{
        CandidateEvidenceField.direction,
        CandidateEvidenceField.occurredAt,
      },
    );

    final decision = engine.decide(
      candidate: candidate,
      deduplication: DeduplicationDecision.unique,
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.pending);
    expect(
      decision.reasons,
      contains(PostingBlockReason.amountEvidenceMissing),
    );
  });

  test('possible duplicate always waits for confirmation', () {
    final decision = engine.decide(
      candidate: testCandidate(),
      deduplication: DeduplicationDecision(
        kind: DeduplicationKind.possibleDuplicate,
        matchedId: 'transaction-1',
        reasons: const <DeduplicationReason>[
          DeduplicationReason.sameAmountCurrencyDirection,
        ],
      ),
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.pending);
    expect(decision.reasons, contains(PostingBlockReason.possibleDuplicate));
  });

  test('refund without original transaction waits for confirmation', () {
    final decision = engine.decide(
      candidate: testCandidate(
        direction: AutomationDirection.refund,
        transactionKind: AutomationTransactionKind.refund,
      ),
      deduplication: DeduplicationDecision.unique,
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.pending);
    expect(
      decision.reasons,
      contains(PostingBlockReason.refundRelationshipMissing),
    );
  });

  test('AI confidence cannot override a transaction semantic conflict', () {
    final decision = engine.decide(
      candidate: testCandidate(
        direction: AutomationDirection.income,
        transactionKind: AutomationTransactionKind.purchase,
        parserConfidence: 0.99,
      ),
      deduplication: DeduplicationDecision.unique,
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.pending);
    expect(
      decision.reasons,
      contains(PostingBlockReason.transactionDirectionConflict),
    );
  });

  test('preauthorization waits for a final transaction update', () {
    final decision = engine.decide(
      candidate: testCandidate(
        transactionKind: AutomationTransactionKind.preauthorization,
      ),
      deduplication: DeduplicationDecision.unique,
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.pending);
    expect(
      decision.reasons,
      contains(PostingBlockReason.preauthorizationNotFinal),
    );
  });

  test('complete credit-card repayment can auto-post as transfer', () {
    final decision = engine.decide(
      candidate: testCandidate(
        direction: AutomationDirection.transfer,
        transactionKind: AutomationTransactionKind.creditCardRepayment,
        toAccountId: 'credit-card-1',
      ),
      deduplication: DeduplicationDecision.unique,
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.autoPost);
    expect(
      decision.command?.transactionKind,
      AutomationTransactionKind.creditCardRepayment,
    );
  });

  test('fee posts as a separate host expense', () {
    final decision = engine.decide(
      candidate: testCandidate(
        transactionKind: AutomationTransactionKind.fee,
      ),
      deduplication: DeduplicationDecision.unique,
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.autoPost);
    expect(decision.command?.hostType, HostTransactionType.expense);
  });

  test('evidence-backed red-packet return posts as new host income', () {
    final decision = engine.decide(
      candidate: testCandidate(
        direction: AutomationDirection.refund,
        transactionKind: AutomationTransactionKind.redPacketReturned,
        relatedTransactionId: 'transaction-1',
        evidenceFields: const <CandidateEvidenceField>{
          CandidateEvidenceField.amount,
          CandidateEvidenceField.direction,
          CandidateEvidenceField.transactionKind,
          CandidateEvidenceField.occurredAt,
          CandidateEvidenceField.relationship,
        },
      ),
      deduplication: DeduplicationDecision.unique,
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.autoPost);
    expect(decision.command?.hostType, HostTransactionType.income);
    expect(decision.command?.relatedTransactionId, 'transaction-1');
  });

  test('unknown or unsplit complex transaction waits for confirmation', () {
    final decision = engine.decide(
      candidate: testCandidate(
        direction: AutomationDirection.unknown,
        transactionKind: AutomationTransactionKind.unknown,
      ),
      deduplication: DeduplicationDecision.unique,
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.pending);
    expect(
      decision.reasons,
      contains(PostingBlockReason.transactionKindUnknown),
    );
  });

  test('disabled optional source does not discard enabled-source evidence', () {
    final time = DateTime.utc(2026, 8, 23, 10);
    final decision = engine.decide(
      candidate: testCandidate(
        additionalSources: <SourceEventReference>[
          SourceEventReference(
            capability: AutomationSourceCapability.accessibility,
            sourceAppId: 'wechat',
            eventIdHash: 'hmac-sha256:accessibility-1',
            lifecycle: PlatformEventLifecycle.snapshotChanged,
            isCurrent: true,
            observedAt: time,
            parserVersion: 1,
          ),
        ],
      ),
      deduplication: DeduplicationDecision.unique,
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.autoPost);
  });

  test('removed optional source does not block a valid notification source',
      () {
    final time = DateTime.utc(2026, 8, 23, 10);
    final decision = engine.decide(
      candidate: testCandidate(
        additionalSources: <SourceEventReference>[
          SourceEventReference(
            capability: AutomationSourceCapability.accessibility,
            sourceAppId: 'wechat',
            eventIdHash: 'hmac-sha256:removed-accessibility-1',
            lifecycle: PlatformEventLifecycle.removed,
            isCurrent: false,
            observedAt: time,
            parserVersion: 1,
          ),
        ],
      ),
      deduplication: DeduplicationDecision.unique,
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.autoPost);
  });

  test('evidence from a disabled capability cannot auto-post', () {
    final time = DateTime.utc(2026, 8, 23, 10);
    final decision = engine.decide(
      candidate: testCandidate(
        capability: AutomationSourceCapability.accessibility,
        additionalSources: <SourceEventReference>[
          SourceEventReference(
            capability: AutomationSourceCapability.notification,
            sourceAppId: 'wechat',
            eventIdHash: 'hmac-sha256:notification-2',
            lifecycle: PlatformEventLifecycle.posted,
            isCurrent: true,
            observedAt: time,
            parserVersion: 1,
          ),
        ],
      ),
      deduplication: DeduplicationDecision.unique,
      policy: enabledPolicy(),
    );

    expect(decision.kind, PostingDecisionKind.pending);
    expect(
      decision.reasons,
      contains(PostingBlockReason.amountEvidenceMissing),
    );
  });

  test('removed event cannot become a current candidate source', () {
    expect(
      () => testCandidate(lifecycle: PlatformEventLifecycle.removed),
      throwsArgumentError,
    );
  });

  test('disabled source is ignored before posting', () {
    final decision = engine.decide(
      candidate: testCandidate(),
      deduplication: DeduplicationDecision.unique,
      policy: PostingPolicy(
        automationEnabled: true,
        enabledSourceAppIds: const <String>{'alipay'},
        enabledCapabilities: const <AutomationSourceCapability>{
          AutomationSourceCapability.notification,
        },
      ),
    );

    expect(decision.kind, PostingDecisionKind.ignored);
    expect(decision.reasons, contains(PostingBlockReason.sourceDisabled));
  });
}
