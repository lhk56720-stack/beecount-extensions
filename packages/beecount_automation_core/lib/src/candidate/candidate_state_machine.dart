import 'package:beecount_extension_api/beecount_extension_api.dart';

final class CandidateTransitionException implements Exception {
  const CandidateTransitionException(this.from, this.to);

  final AutomationCandidateState from;
  final AutomationCandidateState to;

  @override
  String toString() => 'Invalid candidate transition: ${from.name} -> ${to.name}';
}

final class CandidateStateMachine {
  const CandidateStateMachine();

  static const Map<AutomationCandidateState, Set<AutomationCandidateState>>
      _allowed = <AutomationCandidateState, Set<AutomationCandidateState>>{
    AutomationCandidateState.detected: <AutomationCandidateState>{
      AutomationCandidateState.pending,
      AutomationCandidateState.autoPosted,
      AutomationCandidateState.ignored,
      AutomationCandidateState.duplicate,
      AutomationCandidateState.error,
    },
    AutomationCandidateState.pending: <AutomationCandidateState>{
      AutomationCandidateState.confirmed,
      AutomationCandidateState.ignored,
      AutomationCandidateState.duplicate,
      AutomationCandidateState.expired,
      AutomationCandidateState.error,
    },
    AutomationCandidateState.autoPosted: <AutomationCandidateState>{
      AutomationCandidateState.correctionPending,
      AutomationCandidateState.undone,
      AutomationCandidateState.error,
    },
    AutomationCandidateState.confirmed: <AutomationCandidateState>{
      AutomationCandidateState.correctionPending,
    },
    AutomationCandidateState.correctionPending: <AutomationCandidateState>{
      AutomationCandidateState.confirmed,
      AutomationCandidateState.ignored,
      AutomationCandidateState.error,
    },
    AutomationCandidateState.error: <AutomationCandidateState>{
      AutomationCandidateState.pending,
    },
  };

  bool canTransition(
    AutomationCandidateState from,
    AutomationCandidateState to,
  ) {
    return from == to || (_allowed[from]?.contains(to) ?? false);
  }

  AutomationCandidate transition(
    AutomationCandidate candidate,
    AutomationCandidateState nextState,
    DateTime changedAt,
  ) {
    if (candidate.state == nextState) return candidate;
    if (!canTransition(candidate.state, nextState)) {
      throw CandidateTransitionException(candidate.state, nextState);
    }
    if (changedAt.isBefore(candidate.updatedAt)) {
      throw ArgumentError.value(
        changedAt,
        'changedAt',
        'must not be earlier than candidate.updatedAt',
      );
    }
    return candidate.withState(nextState, changedAt);
  }
}
