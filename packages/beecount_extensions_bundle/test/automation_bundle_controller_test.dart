import 'package:beecount_automation_android/beecount_automation_android.dart';
import 'package:beecount_automation_core/beecount_automation_core.dart';
import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:beecount_extensions_bundle/beecount_extensions_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27, 12);

  test('manual confirmation reapplies the latest source account mapping',
      () async {
    final transactions = _FakeTransactionPort();
    final platform = _FakePlatform(
      state: _stateWithCandidate(_candidate(now: now), now: now).toJson(),
      now: now,
    );
    final controller = AutomationBundleController(
      host: _host(now: now, transactions: transactions),
      platform: platform,
    );

    await controller.initialize();
    final result = await controller.confirmCandidate('candidate-1');

    expect(result.succeeded, isTrue);
    expect(transactions.posted.single.accountId, 'account-1');
    expect(transactions.posted.single.ledgerId, 'ledger-1');
    expect(controller.pendingCandidates, isEmpty);
    expect(
      controller.diagnostics.map((item) => item.code),
      contains('confirmation.posted'),
    );
  });

  test('manual confirmation exposes a safe missing amount reason', () async {
    final transactions = _FakeTransactionPort();
    final platform = _FakePlatform(
      state: _stateWithCandidate(
        _candidate(now: now, amountMinor: null, includeAmountEvidence: false),
        now: now,
      ).toJson(),
      now: now,
    );
    final controller = AutomationBundleController(
      host: _host(now: now, transactions: transactions),
      platform: platform,
    );

    await controller.initialize();
    final result = await controller.confirmCandidate('candidate-1');

    expect(result.succeeded, isFalse);
    expect(result.blockReasons, contains(PostingBlockReason.amountMissing));
    expect(transactions.posted, isEmpty);
    expect(
      controller.diagnostics.map((item) => item.code),
      contains('confirmation.blocked.amount_missing'),
    );
  });
}

AutomationBundleState _stateWithCandidate(
  AutomationCandidate candidate, {
  required DateTime now,
}) {
  return AutomationBundleState(
    settings: AutomationSettings(
      automationEnabled: true,
      notificationEnabled: true,
      autoPostEnabled: false,
      enabledSourceAppIds: const <String>{'alipay'},
      sourceAccountIds: const <String, String>{'alipay': 'account-1'},
    ),
    candidates: <AutomationCandidate>[candidate],
    postedTransactionIds: const <String, String>{},
    diagnostics: <AutomationDiagnosticEvent>[
      AutomationDiagnosticEvent(occurredAt: now, code: 'candidate.pending'),
    ],
  );
}

AutomationCandidate _candidate({
  required DateTime now,
  int? amountMinor = 100,
  bool includeAmountEvidence = true,
}) {
  const identity = 'notification:alipay:hmac-sha256:event';
  return AutomationCandidate(
    id: 'candidate-1',
    createdAt: now,
    updatedAt: now,
    occurredAt: now,
    amountMinor: amountMinor,
    currency: amountMinor == null ? null : 'CNY',
    direction: AutomationDirection.expense,
    transactionKind: AutomationTransactionKind.purchase,
    sources: <SourceEventReference>[
      SourceEventReference(
        capability: AutomationSourceCapability.notification,
        sourceAppId: 'alipay',
        eventIdHash: 'hmac-sha256:event',
        lifecycle: PlatformEventLifecycle.posted,
        isCurrent: true,
        observedAt: now,
        parserVersion: 1,
      ),
    ],
    evidence: <CandidateEvidence>[
      if (includeAmountEvidence)
        const CandidateEvidence(
          field: CandidateEvidenceField.amount,
          sourceIdentityKey: identity,
        ),
      if (includeAmountEvidence)
        const CandidateEvidence(
          field: CandidateEvidenceField.currency,
          sourceIdentityKey: identity,
        ),
      const CandidateEvidence(
        field: CandidateEvidenceField.direction,
        sourceIdentityKey: identity,
      ),
      const CandidateEvidence(
        field: CandidateEvidenceField.transactionKind,
        sourceIdentityKey: identity,
      ),
      const CandidateEvidence(
        field: CandidateEvidenceField.occurredAt,
        sourceIdentityKey: identity,
      ),
    ],
    state: AutomationCandidateState.pending,
    parserVersion: 1,
  );
}

HostServices _host({
  required DateTime now,
  required _FakeTransactionPort transactions,
}) {
  return HostServices(
    ledgers: const _FakeLedgerPort(),
    accounts: const _FakeAccountPort(),
    categories: const _FakeCategoryPort(),
    transactions: transactions,
    clock: _FakeClock(now),
    lock: const _FakeLockPort(),
    navigation: const _FakeNavigationPort(),
    logger: const _FakeLogger(),
  );
}

final class _FakePlatform implements AutomationPlatformBridge {
  _FakePlatform({required Map<String, Object?> state, required this.now})
      : _state = state;

  final DateTime now;
  Map<String, Object?>? _state;

  static const _status = NotificationCollectionStatus(
    platformSupported: true,
    accessGranted: true,
    serviceConnected: true,
    automationEnabled: true,
    notificationEnabled: true,
    pendingEventCount: 0,
    enabledPackageNames: <String>{'com.eg.android.AlipayGphone'},
  );

  @override
  Future<NotificationCollectionStatus> configure(
    NotificationCaptureConfiguration configuration,
  ) async =>
      _status;

  @override
  Future<NotificationCollectionStatus> getStatus() async => _status;

  @override
  Future<bool> openNotificationAccessSettings() async => true;

  @override
  Future<Map<String, Object?>?> readLocalState() async => _state;

  @override
  Future<void> writeLocalState(Map<String, Object?> state) async {
    _state = state;
  }

  @override
  Future<void> enqueue(CapturedAutomationEvent event) async {}

  @override
  Future<PlatformEventLease> lease({
    required int limit,
    required Duration leaseDuration,
  }) async {
    return PlatformEventLease(
      token: 'empty-lease',
      expiresAt: now.add(leaseDuration),
      events: const <LeasedPlatformEvent>[],
    );
  }

  @override
  Future<PlatformEventRenewalResult> renew(
    PlatformEventRenewalRequest request,
  ) async {
    return PlatformEventRenewalResult(
      status: PlatformEventMutationStatus.leaseNotFound,
    );
  }

  @override
  Future<PlatformEventMutationResult> acknowledge({
    required String leaseToken,
    required String captureId,
  }) async {
    return const PlatformEventMutationResult(
      status: PlatformEventMutationStatus.applied,
    );
  }

  @override
  Future<PlatformEventMutationResult> release(String leaseToken) async {
    return const PlatformEventMutationResult(
      status: PlatformEventMutationStatus.applied,
    );
  }

  @override
  Future<PlatformEventMutationResult> fail({
    required String leaseToken,
    required String captureId,
    required PlatformEventFailureDisposition disposition,
    required String safeReasonCode,
    DateTime? retryAfter,
  }) async {
    return const PlatformEventMutationResult(
      status: PlatformEventMutationStatus.applied,
    );
  }

  @override
  Future<int> purgeExpired(DateTime now) async => 0;
}

final class _FakeLedgerPort implements LedgerPort {
  const _FakeLedgerPort();

  static const ledger = LedgerSummary(
    id: 'ledger-1',
    name: '测试账本',
    baseCurrency: 'CNY',
    isWritable: true,
  );

  @override
  Future<LedgerSummary?> getCurrentLedger() async => ledger;

  @override
  Future<LedgerSummary?> getLedger(String ledgerId) async => ledger;

  @override
  Future<List<LedgerSummary>> listLedgers() async => const <LedgerSummary>[
        ledger,
      ];
}

final class _FakeAccountPort implements AccountPort {
  const _FakeAccountPort();

  static const account = AccountSummary(
    id: 'account-1',
    name: '支付宝',
    currency: 'CNY',
    isEnabled: true,
  );

  @override
  Future<AccountSummary?> getAccount(String accountId) async => account;

  @override
  Future<List<AccountSummary>> listAccounts({
    required String ledgerId,
    String? currency,
  }) async =>
      const <AccountSummary>[account];
}

final class _FakeCategoryPort implements CategoryPort {
  const _FakeCategoryPort();

  @override
  Future<CategorySummary?> getCategory(String categoryId) async => null;

  @override
  Future<List<CategorySummary>> listUsableCategories({
    required String ledgerId,
    required AutomationDirection direction,
  }) async =>
      const <CategorySummary>[];
}

final class _FakeTransactionPort implements TransactionPort {
  final List<PostingCommand> posted = <PostingCommand>[];

  @override
  Future<HostTransactionSummary?> getTransaction(String transactionId) async =>
      null;

  @override
  Future<List<HostTransactionSummary>> listRecentTransactions({
    required String ledgerId,
    required DateTime from,
    required DateTime to,
  }) async =>
      const <HostTransactionSummary>[];

  @override
  Future<PostingResult> postCandidate(PostingCommand command) async {
    posted.add(command);
    return const PostingResult(
      status: PostingResultStatus.created,
      transactionId: 'transaction-1',
    );
  }
}

final class _FakeClock implements ClockPort {
  const _FakeClock(this.now);

  @override
  final DateTime now;
}

final class _FakeLockPort implements LockPort {
  const _FakeLockPort();

  @override
  Future<bool> isLocked() async => false;

  @override
  Future<bool> requestUnlock({required String reason}) async => true;
}

final class _FakeNavigationPort implements NavigationPort {
  const _FakeNavigationPort();

  @override
  Future<void> openCandidate({required String candidateId}) async {}

  @override
  Future<void> openCandidateList() async {}

  @override
  Future<void> openTransaction({required String transactionId}) async {}
}

final class _FakeLogger implements SafeLogger {
  const _FakeLogger();

  @override
  void debug(String code, {Map<String, Object?> fields = const {}}) {}

  @override
  void error(String code, {Map<String, Object?> fields = const {}}) {}

  @override
  void warning(String code, {Map<String, Object?> fields = const {}}) {}
}
