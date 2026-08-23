import '../model/automation_candidate.dart';
import '../model/host_models.dart';

abstract interface class LedgerPort {
  Future<LedgerSummary?> getCurrentLedger();

  Future<LedgerSummary?> getLedger(String ledgerId);

  Future<List<LedgerSummary>> listLedgers();
}

abstract interface class AccountPort {
  Future<List<AccountSummary>> listAccounts({
    required String ledgerId,
    String? currency,
  });

  Future<AccountSummary?> getAccount(String accountId);
}

abstract interface class CategoryPort {
  /// A refund direction is adapted to BeeCount's income category tree while
  /// retaining refund semantics in extension metadata.
  Future<List<CategorySummary>> listUsableCategories({
    required String ledgerId,
    required AutomationDirection direction,
  });

  Future<CategorySummary?> getCategory(String categoryId);
}

abstract interface class TransactionPort {
  Future<List<HostTransactionSummary>> listRecentTransactions({
    required String ledgerId,
    required DateTime from,
    required DateTime to,
  });

  /// Creates one new formal transaction without mutating a related original.
  ///
  /// A refund command uses [HostTransactionType.income] while retaining
  /// refund semantics and [PostingCommand.relatedTransactionId] in extension
  /// metadata. Reusing an idempotency key with an identical command returns
  /// [PostingResultStatus.alreadyApplied]; reusing it with a different command
  /// returns [PostingResultStatus.idempotencyConflict] without writing.
  Future<PostingResult> postCandidate(PostingCommand command);

  Future<HostTransactionSummary?> getTransaction(String transactionId);
}

abstract interface class ClockPort {
  DateTime get now;
}

abstract interface class LockPort {
  Future<bool> isLocked();

  Future<bool> requestUnlock({required String reason});
}

abstract interface class NavigationPort {
  Future<void> openCandidateList();

  Future<void> openCandidate({required String candidateId});

  Future<void> openTransaction({required String transactionId});
}

abstract interface class SafeLogger {
  void debug(String code, {Map<String, Object?> fields = const {}});

  void warning(String code, {Map<String, Object?> fields = const {}});

  void error(String code, {Map<String, Object?> fields = const {}});
}

final class HostServices {
  const HostServices({
    required this.ledgers,
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.clock,
    required this.lock,
    required this.navigation,
    required this.logger,
  });

  final LedgerPort ledgers;
  final AccountPort accounts;
  final CategoryPort categories;
  final TransactionPort transactions;
  final ClockPort clock;
  final LockPort lock;
  final NavigationPort navigation;
  final SafeLogger logger;
}
