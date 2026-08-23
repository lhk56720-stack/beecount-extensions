import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:test/test.dart';

void main() {
  CapturedAutomationEvent event() {
    return CapturedAutomationEvent(
      id: 'capture-1',
      source: CapturedEventSource(
        capability: AutomationSourceCapability.notification,
        sourceAppId: 'wechat',
        packageName: 'com.tencent.mm',
        eventId: 'notification-1',
        eventIdHash: 'hmac-sha256:notification-1',
        observedAt: DateTime.utc(2026, 8, 23, 10),
      ),
      lifecycle: PlatformEventLifecycle.posted,
      capturedAt: DateTime.utc(2026, 8, 23, 10),
      textFragments: const <CapturedTextFragment>[
        CapturedTextFragment(
          role: CapturedTextRole.body,
          value: 'synthetic payment text',
        ),
      ],
    );
  }

  AutomationCandidate candidateFor(
    CapturedAutomationEvent input, {
    String id = 'candidate-1',
    AutomationCandidateState state = AutomationCandidateState.detected,
  }) {
    final source = input.source.toCandidateReference(
      parserVersion: 1,
      lifecycle: input.lifecycle,
      isCurrent: true,
    );
    return AutomationCandidate(
      id: id,
      targetLedgerId: 'ledger-1',
      createdAt: input.capturedAt,
      updatedAt: input.capturedAt,
      occurredAt: input.source.observedAt,
      amountMinor: 1280,
      currency: 'CNY',
      direction: AutomationDirection.expense,
      transactionKind: AutomationTransactionKind.purchase,
      resolvedAccountId: 'account-1',
      sources: <SourceEventReference>[source],
      evidence: <CandidateEvidence>[
        CandidateEvidence(
          field: CandidateEvidenceField.amount,
          sourceIdentityKey: source.identityKey,
        ),
      ],
      state: state,
      parserVersion: 1,
    );
  }

  test('captured text collection is immutable and memory-oriented', () {
    final captured = event();

    expect(captured.hasText, isTrue);
    expect(
      () => captured.textFragments.add(
        const CapturedTextFragment(
          role: CapturedTextRole.title,
          value: 'unexpected',
        ),
      ),
      throwsUnsupportedError,
    );
    expect(
      captured.source.identityKey,
      'notification:wechat:hmac-sha256:notification-1',
    );
  });

  test('candidate disposition requires a candidate', () {
    expect(
      () => AutomationParserResult(
        event: event(),
        disposition: ParserDisposition.candidate,
      ),
      throwsArgumentError,
    );
  });

  test('parser issues cannot be mutated after construction', () {
    final result = AutomationParserResult(
      event: event(),
      disposition: ParserDisposition.incomplete,
      issues: const <ParserIssueCode>[ParserIssueCode.missingAmount],
    );

    expect(
      () => result.issues.add(ParserIssueCode.missingDirection),
      throwsUnsupportedError,
    );
  });

  test('one event may produce multiple immutable candidates', () {
    final input = event();
    final result = AutomationParserResult(
      event: input,
      disposition: ParserDisposition.candidate,
      candidates: <AutomationCandidate>[
        candidateFor(input),
        candidateFor(input, id: 'candidate-fee-1'),
      ],
    );

    expect(result.candidates, hasLength(2));
    expect(
      () => result.candidates.add(candidateFor(input, id: 'unexpected')),
      throwsUnsupportedError,
    );
  });

  test('parser cannot emit a completed candidate state', () {
    final input = event();

    expect(
      () => AutomationParserResult(
        event: input,
        disposition: ParserDisposition.candidate,
        candidates: <AutomationCandidate>[
          candidateFor(input, state: AutomationCandidateState.autoPosted),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('removed platform event is a lifecycle signal, not a reversal', () {
    final removed = CapturedAutomationEvent(
      id: 'capture-2',
      source: event().source,
      lifecycle: PlatformEventLifecycle.removed,
      capturedAt: DateTime.utc(2026, 8, 23, 10, 1),
      textFragments: const <CapturedTextFragment>[],
    );

    expect(removed.lifecycle, PlatformEventLifecycle.removed);
    expect(removed.hasText, isFalse);
    expect(removed.isParseable, isFalse);
    expect(
      AutomationParserResult(
        event: removed,
        disposition: ParserDisposition.ignored,
      ).candidates,
      isEmpty,
    );
  });

  test('removed platform event rejects copied text', () {
    expect(
      () => CapturedAutomationEvent(
        id: 'capture-3',
        source: event().source,
        lifecycle: PlatformEventLifecycle.removed,
        capturedAt: DateTime.utc(2026, 8, 23, 10, 2),
        textFragments: const <CapturedTextFragment>[
          CapturedTextFragment(
            role: CapturedTextRole.body,
            value: 'must not survive removal',
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
