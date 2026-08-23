import 'package:beecount_extension_api/beecount_extension_api.dart';

enum AccountMappingMatchKind {
  none,
  alreadyResolved,
  exactToken,
  sourceDefault,
}

final class AccountMappingRule {
  const AccountMappingRule({
    required this.id,
    required this.ledgerId,
    required this.sourceAppId,
    required this.accountId,
    required this.enabled,
    required this.isSourceDefault,
    this.accountHintToken,
    this.currency,
  });

  final String id;
  final String ledgerId;
  final String sourceAppId;
  final String accountId;
  final bool enabled;
  final bool isSourceDefault;
  final String? accountHintToken;
  final String? currency;
}

final class AccountMappingDecision {
  const AccountMappingDecision({
    required this.kind,
    this.accountId,
    this.ruleId,
  });

  final AccountMappingMatchKind kind;
  final String? accountId;
  final String? ruleId;
}

final class AccountMappingEngine {
  const AccountMappingEngine();

  AccountMappingDecision resolve(
    AutomationCandidate candidate,
    Iterable<AccountMappingRule> rules,
  ) {
    final resolved = candidate.resolvedAccountId;
    if (resolved != null) {
      return AccountMappingDecision(
        kind: AccountMappingMatchKind.alreadyResolved,
        accountId: resolved,
      );
    }

    final ledgerId = candidate.targetLedgerId;
    if (ledgerId == null) {
      return const AccountMappingDecision(kind: AccountMappingMatchKind.none);
    }

    final sourceIds = candidate.sources.map((item) => item.sourceAppId).toSet();
    final eligible = rules.where((rule) {
      if (!rule.enabled || rule.ledgerId != ledgerId) return false;
      if (!sourceIds.contains(rule.sourceAppId)) return false;
      final ruleCurrency = rule.currency;
      return ruleCurrency == null || ruleCurrency == candidate.currency;
    }).toList(growable: false);

    final token = candidate.accountHintToken;
    if (token != null) {
      for (final rule in eligible) {
        if (rule.accountHintToken == token) {
          return AccountMappingDecision(
            kind: AccountMappingMatchKind.exactToken,
            accountId: rule.accountId,
            ruleId: rule.id,
          );
        }
      }
    }

    final defaults = eligible.where((rule) => rule.isSourceDefault).toList();
    if (defaults.length == 1) {
      final rule = defaults.single;
      return AccountMappingDecision(
        kind: AccountMappingMatchKind.sourceDefault,
        accountId: rule.accountId,
        ruleId: rule.id,
      );
    }

    return const AccountMappingDecision(kind: AccountMappingMatchKind.none);
  }
}
