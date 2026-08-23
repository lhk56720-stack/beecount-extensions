import 'package:beecount_automation_core/beecount_automation_core.dart';
import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:test/test.dart';

import 'test_candidate.dart';

void main() {
  const machine = CandidateStateMachine();

  test('detected candidate can become auto-posted', () {
    final candidate = testCandidate();
    final changedAt = candidate.updatedAt.add(const Duration(seconds: 1));

    final result = machine.transition(
      candidate,
      AutomationCandidateState.autoPosted,
      changedAt,
    );

    expect(result.state, AutomationCandidateState.autoPosted);
    expect(result.updatedAt, changedAt);
  });

  test('terminal duplicate candidate cannot become auto-posted', () {
    final candidate = testCandidate(
      state: AutomationCandidateState.duplicate,
    );

    expect(
      () => machine.transition(
        candidate,
        AutomationCandidateState.autoPosted,
        candidate.updatedAt,
      ),
      throwsA(isA<CandidateTransitionException>()),
    );
  });

  test('repeating the same transition is idempotent', () {
    final candidate = testCandidate(
      state: AutomationCandidateState.pending,
    );

    expect(
      identical(
        candidate,
        machine.transition(
          candidate,
          AutomationCandidateState.pending,
          candidate.updatedAt,
        ),
      ),
      isTrue,
    );
  });
}
