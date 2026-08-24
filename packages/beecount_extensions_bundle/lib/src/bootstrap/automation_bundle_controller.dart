import 'package:beecount_automation_android/beecount_automation_android.dart';
import 'package:beecount_automation_core/beecount_automation_core.dart';
import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:flutter/foundation.dart';

import '../model/automation_bundle_state.dart';
import 'automation_platform_bridge.dart';

/// Foreground coordinator for notification-first automatic bookkeeping.
///
/// The controller intentionally never retains raw notification payloads after a
/// parser result has been persisted. Native code owns the short-lived recovery
/// queue; this class owns structured candidates and all host writes.
final class AutomationBundleController extends ChangeNotifier {
  AutomationBundleController({
    required HostServices host,
    AutomationPlatformBridge? platform,
    Set<String> verifiedAutoPostSourceAppIds = const <String>{},
  })  : _host = host,
        _platform = platform ?? AndroidAutomationPlatformBridge(),
        _verifiedAutoPostSourceAppIds =
            Set<String>.unmodifiable(verifiedAutoPostSourceAppIds),
        _parser = NotificationEventParser(
          supportedSourceAppIds: NotificationSourceRegistry.supported
              .map((source) => source.id)
              .toSet(),
        );

  final HostServices _host;
  final AutomationPlatformBridge _platform;
  final Set<String> _verifiedAutoPostSourceAppIds;
  final NotificationEventParser _parser;
  final DeduplicationEngine _deduplication = const DeduplicationEngine();
  final PostingDecisionEngine _posting = const PostingDecisionEngine();
  final CandidateStateMachine _stateMachine = const CandidateStateMachine();

  AutomationBundleState _state = AutomationBundleState.defaults();
  NotificationCollectionStatus? _collectionStatus;
  List<LedgerSummary> _ledgers = const <LedgerSummary>[];
  List<AccountSummary> _accounts = const <AccountSummary>[];
  bool _initialized = false;
  bool _processing = false;
  String? _safeErrorCode;

  bool get initialized => _initialized;
  bool get processing => _processing;
  String? get safeErrorCode => _safeErrorCode;
  AutomationSettings get settings => _state.settings;
  List<AutomationCandidate> get candidates => _state.candidates;
  NotificationCollectionStatus? get collectionStatus => _collectionStatus;
  List<LedgerSummary> get ledgers => _ledgers;
  List<AccountSummary> get accounts => _accounts;

  List<AutomationCandidate> get pendingCandidates => candidates
      .where((candidate) =>
          candidate.state == AutomationCandidateState.detected ||
          candidate.state == AutomationCandidateState.pending ||
          candidate.state == AutomationCandidateState.error)
      .toList(growable: false);

  Future<void> initialize() async {
    if (_initialized) return;
    final saved = await _platform.readLocalState();
    if (saved != null) {
      try {
        _state = AutomationBundleState.fromJson(saved);
      } catch (_) {
        _safeErrorCode = 'automation.local_state_invalid';
      }
    }
    await _refreshHostChoices();
    await _synchronizeCapture();
    _initialized = true;
    notifyListeners();
    await processQueuedEvents();
  }

  Future<void> refresh() async {
    await _refreshHostChoices();
    await _synchronizeCapture();
    notifyListeners();
    await processQueuedEvents();
  }

  Future<bool> openNotificationAccessSettings() =>
      _platform.openNotificationAccessSettings();

  Future<void> updateSettings(AutomationSettings next) async {
    _state = AutomationBundleState(
      settings: next,
      candidates: _state.candidates,
      postedTransactionIds: _state.postedTransactionIds,
    );
    await _persist();
    await _synchronizeCapture();
    notifyListeners();
    await processQueuedEvents();
  }

  Future<void> processQueuedEvents() async {
    if (!_initialized || _processing) return;
    if (!settings.automationEnabled || !settings.notificationEnabled) return;
    _processing = true;
    notifyListeners();
    try {
      while (true) {
        final lease = await _platform.lease(
          limit: 20,
          leaseDuration: const Duration(minutes: 2),
        );
        if (lease.events.isEmpty) break;
        for (final leased in lease.events) {
          await _consumeLeasedEvent(lease.token, leased);
        }
      }
      _collectionStatus = await _platform.getStatus();
      _safeErrorCode = null;
    } catch (_) {
      _safeErrorCode = 'automation.queue_process_failed';
      _host.logger.warning('automation.queue_process_failed');
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  Future<bool> confirmCandidate(String candidateId) async {
    final candidate = _candidateById(candidateId);
    if (candidate == null) return false;
    final decision = await _decide(
      candidate,
      allowUnverifiedSourceForManualConfirmation: true,
    );
    if (decision.kind != PostingDecisionKind.autoPost ||
        decision.command == null) {
      _replaceCandidate(_asPending(candidate));
      await _persist();
      notifyListeners();
      return false;
    }
    await _post(candidate, decision.command!, isManual: true);
    return true;
  }

  Future<void> ignoreCandidate(String candidateId) async {
    final candidate = _candidateById(candidateId);
    if (candidate == null) return;
    _replaceCandidate(
      _stateMachine.transition(
        _asPending(candidate),
        AutomationCandidateState.ignored,
        _host.clock.now,
      ),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> _consumeLeasedEvent(
    String leaseToken,
    LeasedPlatformEvent leased,
  ) async {
    final result = await _parser.parse(leased.event);
    if (result.disposition == ParserDisposition.retryableFailure) {
      await _platform.fail(
        leaseToken: leaseToken,
        captureId: leased.event.id,
        disposition: PlatformEventFailureDisposition.retryable,
        safeReasonCode: result.safeReasonCode ?? 'parser.retryable_failure',
        retryAfter: _host.clock.now.add(const Duration(minutes: 1)),
      );
      return;
    }
    if (result.disposition == ParserDisposition.permanentFailure) {
      await _platform.fail(
        leaseToken: leaseToken,
        captureId: leased.event.id,
        disposition: PlatformEventFailureDisposition.permanent,
        safeReasonCode: result.safeReasonCode ?? 'parser.permanent_failure',
      );
      return;
    }
    for (final parsed in result.candidates) {
      final candidate = await _resolveCandidate(parsed);
      _replaceCandidate(candidate);
      await _persist();
      await _tryAutomaticPosting(candidate);
    }
    await _platform.acknowledge(
      leaseToken: leaseToken,
      captureId: leased.event.id,
    );
  }

  Future<void> _tryAutomaticPosting(AutomationCandidate candidate) async {
    if (!settings.autoPostEnabled) {
      _replaceCandidate(_asPending(candidate));
      await _persist();
      return;
    }
    final decision = await _decide(candidate);
    switch (decision.kind) {
      case PostingDecisionKind.autoPost:
        await _post(candidate, decision.command!, isManual: false);
        return;
      case PostingDecisionKind.duplicate:
        _replaceCandidate(
          _stateMachine.transition(
            _asPending(candidate),
            AutomationCandidateState.duplicate,
            _host.clock.now,
          ),
        );
        await _persist();
        return;
      case PostingDecisionKind.pending:
      case PostingDecisionKind.ignored:
      case PostingDecisionKind.updateExisting:
        _replaceCandidate(_asPending(candidate));
        await _persist();
        return;
    }
  }

  Future<void> _post(
    AutomationCandidate candidate,
    PostingCommand command, {
    required bool isManual,
  }) async {
    final beforePosting = _asPending(candidate);
    _replaceCandidate(beforePosting);
    await _persist();
    final result = await _host.transactions.postCandidate(command);
    if (result.status == PostingResultStatus.created ||
        result.status == PostingResultStatus.alreadyApplied) {
      final targetState = isManual
          ? AutomationCandidateState.confirmed
          : AutomationCandidateState.autoPosted;
      final transitionSource =
          targetState == AutomationCandidateState.autoPosted
              ? candidate
              : beforePosting;
      _replaceCandidate(
        _stateMachine.transition(
            transitionSource, targetState, _host.clock.now),
      );
      if (result.transactionId != null) {
        _state = AutomationBundleState(
          settings: _state.settings,
          candidates: _state.candidates,
          postedTransactionIds: <String, String>{
            ..._state.postedTransactionIds,
            candidate.id: result.transactionId!,
          },
        );
      }
    } else {
      _replaceCandidate(
        _stateMachine.transition(
          beforePosting,
          AutomationCandidateState.error,
          _host.clock.now,
        ),
      );
      _safeErrorCode = result.safeErrorCode ?? 'automation.post_rejected';
    }
    await _persist();
    notifyListeners();
  }

  Future<PostingDecision> _decide(
    AutomationCandidate candidate, {
    bool allowUnverifiedSourceForManualConfirmation = false,
  }) async {
    final existing = <DeduplicationFact>[
      for (final item in _state.candidates)
        if (item.id != candidate.id) DeduplicationFact.fromCandidate(item),
    ];
    final ledgerId = candidate.targetLedgerId;
    if (ledgerId != null) {
      final transactions = await _host.transactions.listRecentTransactions(
        ledgerId: ledgerId,
        from: candidate.occurredAt.subtract(const Duration(minutes: 5)),
        to: candidate.occurredAt.add(const Duration(minutes: 5)),
      );
      existing.addAll(transactions.map(DeduplicationFact.fromHostTransaction));
    }
    final trustedSources = allowUnverifiedSourceForManualConfirmation
        ? candidate.sources.map((source) => source.sourceAppId).toSet()
        : _verifiedAutoPostSourceAppIds;
    return _posting.decide(
      candidate: candidate,
      deduplication: _deduplication.evaluate(candidate, existing),
      policy: PostingPolicy(
        automationEnabled: true,
        enabledSourceAppIds: settings.enabledSourceAppIds,
        enabledCapabilities: const <AutomationSourceCapability>{
          AutomationSourceCapability.notification,
        },
        verifiedAutoPostSourceAppIds: trustedSources,
      ),
    );
  }

  Future<AutomationCandidate> _resolveCandidate(
    AutomationCandidate candidate,
  ) async {
    final currentLedger = settings.targetLedgerId == null
        ? await _host.ledgers.getCurrentLedger()
        : await _host.ledgers.getLedger(settings.targetLedgerId!);
    final sourceId = candidate.sources.first.sourceAppId;
    return _copyCandidate(
      candidate,
      targetLedgerId:
          currentLedger?.isWritable == true ? currentLedger!.id : null,
      accountId: settings.sourceAccountIds[sourceId],
    );
  }

  Future<void> _refreshHostChoices() async {
    _ledgers = await _host.ledgers.listLedgers();
    final ledgerId =
        settings.targetLedgerId ?? (await _host.ledgers.getCurrentLedger())?.id;
    _accounts = ledgerId == null
        ? const <AccountSummary>[]
        : await _host.accounts
            .listAccounts(ledgerId: ledgerId, currency: 'CNY');
  }

  Future<void> _synchronizeCapture() async {
    final packages = NotificationSourceRegistry.supported
        .where((source) => settings.enabledSourceAppIds.contains(source.id))
        .map((source) => source.packageName)
        .toSet();
    _collectionStatus = await _platform.configure(
      NotificationCaptureConfiguration(
        automationEnabled: settings.automationEnabled,
        notificationEnabled: settings.notificationEnabled,
        enabledPackageNames: packages,
      ),
    );
  }

  AutomationCandidate? _candidateById(String id) {
    for (final candidate in _state.candidates) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  AutomationCandidate _asPending(AutomationCandidate candidate) {
    if (candidate.state == AutomationCandidateState.pending) return candidate;
    if (candidate.state != AutomationCandidateState.detected &&
        candidate.state != AutomationCandidateState.error) {
      return candidate;
    }
    return _stateMachine.transition(
      candidate,
      AutomationCandidateState.pending,
      _host.clock.now,
    );
  }

  void _replaceCandidate(AutomationCandidate candidate) {
    final next = <AutomationCandidate>[
      for (final existing in _state.candidates)
        if (existing.id != candidate.id) existing,
      candidate,
    ]..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    if (next.length > 500) next.removeRange(500, next.length);
    _state = AutomationBundleState(
      settings: _state.settings,
      candidates: next,
      postedTransactionIds: _state.postedTransactionIds,
    );
  }

  Future<void> _persist() => _platform.writeLocalState(_state.toJson());
}

AutomationCandidate _copyCandidate(
  AutomationCandidate candidate, {
  String? targetLedgerId,
  String? accountId,
}) {
  return AutomationCandidate(
    id: candidate.id,
    targetLedgerId: targetLedgerId,
    createdAt: candidate.createdAt,
    updatedAt: candidate.updatedAt,
    occurredAt: candidate.occurredAt,
    amountMinor: candidate.amountMinor,
    currency: candidate.currency,
    direction: candidate.direction,
    transactionKind: candidate.transactionKind,
    merchant: candidate.merchant,
    note: candidate.note,
    accountHintToken: candidate.accountHintToken,
    resolvedAccountId: accountId,
    resolvedToAccountId: candidate.resolvedToAccountId,
    resolvedCategoryId: candidate.resolvedCategoryId,
    categoryHint: candidate.categoryHint,
    relatedTransactionId: candidate.relatedTransactionId,
    stableTransactionIdHash: candidate.stableTransactionIdHash,
    sources: candidate.sources,
    evidence: candidate.evidence,
    parserConfidence: candidate.parserConfidence,
    state: candidate.state,
    parserVersion: candidate.parserVersion,
  );
}
