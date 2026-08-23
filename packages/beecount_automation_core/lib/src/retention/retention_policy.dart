import 'package:beecount_extension_api/beecount_extension_api.dart';

enum CandidateRetentionAction {
  keep,
  expire,
  delete,
}

final class AutomationRetentionPolicy {
  const AutomationRetentionPolicy({
    this.pendingCandidateTtl = const Duration(days: 7),
    this.ephemeralRawTtl = const Duration(hours: 24),
    this.autoPostUndoWindow = const Duration(minutes: 10),
  });

  final Duration pendingCandidateTtl;
  final Duration ephemeralRawTtl;
  final Duration autoPostUndoWindow;

  DateTime ephemeralRawExpiresAt(DateTime firstEnqueuedAt) {
    return firstEnqueuedAt.add(ephemeralRawTtl);
  }

  DateTime autoPostUndoDeadline(DateTime postedAt) {
    return postedAt.add(autoPostUndoWindow);
  }

  bool canUndoAutoPost({
    required DateTime postedAt,
    required DateTime now,
  }) {
    return !now.isAfter(autoPostUndoDeadline(postedAt));
  }

  CandidateRetentionAction actionFor(
    AutomationCandidate candidate,
    DateTime now,
  ) {
    switch (candidate.state) {
      case AutomationCandidateState.detected:
      case AutomationCandidateState.pending:
      case AutomationCandidateState.correctionPending:
      case AutomationCandidateState.error:
        final expiresAt = candidate.updatedAt.add(pendingCandidateTtl);
        return now.isAfter(expiresAt)
            ? CandidateRetentionAction.expire
            : CandidateRetentionAction.keep;
      case AutomationCandidateState.ignored:
      case AutomationCandidateState.duplicate:
      case AutomationCandidateState.expired:
        return CandidateRetentionAction.delete;
      case AutomationCandidateState.autoPosted:
      case AutomationCandidateState.confirmed:
      case AutomationCandidateState.undone:
        return CandidateRetentionAction.keep;
    }
  }
}
