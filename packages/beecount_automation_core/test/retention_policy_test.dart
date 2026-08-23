import 'package:beecount_automation_core/beecount_automation_core.dart';
import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:test/test.dart';

import 'test_candidate.dart';

void main() {
  const policy = AutomationRetentionPolicy();

  test('pending candidate expires after seven days', () {
    final candidate = testCandidate(
      state: AutomationCandidateState.pending,
    );

    expect(
      policy.actionFor(
        candidate,
        candidate.updatedAt.add(const Duration(days: 7, seconds: 1)),
      ),
      CandidateRetentionAction.expire,
    );
  });

  test('raw recovery lifetime is fixed at 24 hours from first enqueue', () {
    final firstEnqueuedAt = DateTime.utc(2026, 8, 23, 10);

    expect(
      policy.ephemeralRawExpiresAt(firstEnqueuedAt),
      DateTime.utc(2026, 8, 24, 10),
    );
  });

  test('auto-post undo window is inclusive at ten minutes', () {
    final postedAt = DateTime.utc(2026, 8, 23, 10);

    expect(
      policy.canUndoAutoPost(
        postedAt: postedAt,
        now: postedAt.add(const Duration(minutes: 10)),
      ),
      isTrue,
    );
    expect(
      policy.canUndoAutoPost(
        postedAt: postedAt,
        now: postedAt.add(const Duration(minutes: 10, milliseconds: 1)),
      ),
      isFalse,
    );
  });
}
