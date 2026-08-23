import 'package:beecount_extension_api/beecount_extension_api.dart';

enum DeduplicationKind {
  unique,
  update,
  duplicate,
  possibleDuplicate,
}

enum DeduplicationReason {
  sameCandidate,
  sameSourceEvent,
  supersededSourceEvent,
  stableTransactionId,
  sameAmountCurrencyDirection,
  withinTimeWindow,
  sameMerchant,
  sameAccount,
  crossSource,
}

final class DeduplicationDecision {
  DeduplicationDecision({
    required this.kind,
    required List<DeduplicationReason> reasons,
    this.matchedId,
  }) : reasons = List<DeduplicationReason>.unmodifiable(reasons);

  final DeduplicationKind kind;
  final String? matchedId;
  final List<DeduplicationReason> reasons;

  static final DeduplicationDecision unique = DeduplicationDecision(
    kind: DeduplicationKind.unique,
    reasons: const <DeduplicationReason>[],
  );
}

final class DeduplicationFact {
  DeduplicationFact({
    required this.id,
    required this.occurredAt,
    required this.amountMinor,
    required this.currency,
    required this.direction,
    required Set<String> sourceIdentityKeys,
    required Set<String> sourceAppIds,
    required Set<AutomationSourceCapability> sourceCapabilities,
    this.merchant,
    this.accountId,
    this.stableTransactionIdHash,
  })  : sourceIdentityKeys = Set<String>.unmodifiable(sourceIdentityKeys),
        sourceAppIds = Set<String>.unmodifiable(sourceAppIds),
        sourceCapabilities =
            Set<AutomationSourceCapability>.unmodifiable(sourceCapabilities);

  final String id;
  final DateTime occurredAt;
  final int? amountMinor;
  final String? currency;
  final AutomationDirection direction;
  final String? merchant;
  final String? accountId;
  final String? stableTransactionIdHash;
  final Set<String> sourceIdentityKeys;
  final Set<String> sourceAppIds;
  final Set<AutomationSourceCapability> sourceCapabilities;

  factory DeduplicationFact.fromCandidate(AutomationCandidate candidate) {
    return DeduplicationFact(
      id: candidate.id,
      occurredAt: candidate.occurredAt,
      amountMinor: candidate.amountMinor,
      currency: candidate.currency,
      direction: candidate.direction,
      merchant: candidate.merchant,
      accountId: candidate.resolvedAccountId,
      stableTransactionIdHash: candidate.stableTransactionIdHash,
      sourceIdentityKeys:
          candidate.sources.map((source) => source.identityKey).toSet(),
      sourceAppIds:
          candidate.sources.map((source) => source.sourceAppId).toSet(),
      sourceCapabilities:
          candidate.sources.map((source) => source.capability).toSet(),
    );
  }

  factory DeduplicationFact.fromHostTransaction(
    HostTransactionSummary transaction,
  ) {
    return DeduplicationFact(
      id: transaction.id,
      occurredAt: transaction.occurredAt,
      amountMinor: transaction.amountMinor,
      currency: transaction.currency,
      direction: transaction.direction,
      merchant: transaction.merchant,
      accountId: transaction.accountId,
      stableTransactionIdHash: transaction.stableTransactionIdHash,
      sourceIdentityKeys: const <String>{},
      sourceAppIds: const <String>{},
      sourceCapabilities: const <AutomationSourceCapability>{},
    );
  }
}

final class DeduplicationEngine {
  const DeduplicationEngine({
    this.fuzzyWindow = const Duration(minutes: 3),
  });

  final Duration fuzzyWindow;

  DeduplicationDecision evaluate(
    AutomationCandidate candidate,
    Iterable<DeduplicationFact> existing,
  ) {
    final incoming = DeduplicationFact.fromCandidate(candidate);
    DeduplicationDecision? possible;

    for (final item in existing) {
      final direct = _directMatch(candidate, incoming, item);
      if (direct != null) return direct;

      final fuzzy = _fuzzyMatch(incoming, item);
      if (fuzzy?.kind == DeduplicationKind.duplicate) return fuzzy!;
      possible ??= fuzzy;
    }

    return possible ?? DeduplicationDecision.unique;
  }

  DeduplicationDecision? _directMatch(
    AutomationCandidate candidate,
    DeduplicationFact incoming,
    DeduplicationFact existing,
  ) {
    if (incoming.id == existing.id) {
      return DeduplicationDecision(
        kind: DeduplicationKind.update,
        matchedId: existing.id,
        reasons: const <DeduplicationReason>[
          DeduplicationReason.sameCandidate,
        ],
      );
    }

    if (incoming.sourceIdentityKeys.intersection(existing.sourceIdentityKeys).isNotEmpty) {
      return DeduplicationDecision(
        kind: DeduplicationKind.update,
        matchedId: existing.id,
        reasons: const <DeduplicationReason>[
          DeduplicationReason.sameSourceEvent,
        ],
      );
    }

    for (final source in candidate.sources) {
      final superseded = source.supersedesEventIdHash;
      if (superseded == null) continue;
      final key = '${source.capability.name}:${source.sourceAppId}:$superseded';
      if (existing.sourceIdentityKeys.contains(key)) {
        return DeduplicationDecision(
          kind: DeduplicationKind.update,
          matchedId: existing.id,
          reasons: const <DeduplicationReason>[
            DeduplicationReason.supersededSourceEvent,
          ],
        );
      }
    }

    final stableId = incoming.stableTransactionIdHash;
    if (stableId != null && stableId == existing.stableTransactionIdHash) {
      return DeduplicationDecision(
        kind: DeduplicationKind.duplicate,
        matchedId: existing.id,
        reasons: const <DeduplicationReason>[
          DeduplicationReason.stableTransactionId,
        ],
      );
    }
    return null;
  }

  DeduplicationDecision? _fuzzyMatch(
    DeduplicationFact incoming,
    DeduplicationFact existing,
  ) {
    if (incoming.amountMinor == null || incoming.currency == null) return null;
    if (incoming.amountMinor != existing.amountMinor ||
        incoming.currency != existing.currency ||
        incoming.direction != existing.direction) {
      return null;
    }

    final distanceMs =
        incoming.occurredAt.difference(existing.occurredAt).inMilliseconds.abs();
    if (distanceMs > fuzzyWindow.inMilliseconds) return null;

    final reasons = <DeduplicationReason>[
      DeduplicationReason.sameAmountCurrencyDirection,
      DeduplicationReason.withinTimeWindow,
    ];
    final merchantMatches = _normalizedMerchant(incoming.merchant) != null &&
        _normalizedMerchant(incoming.merchant) ==
            _normalizedMerchant(existing.merchant);
    final accountMatches = incoming.accountId != null &&
        incoming.accountId == existing.accountId;
    final hasComparableSource = incoming.sourceCapabilities.isNotEmpty &&
        existing.sourceCapabilities.isNotEmpty &&
        incoming.sourceAppIds.isNotEmpty &&
        existing.sourceAppIds.isNotEmpty;
    final crossSource = hasComparableSource &&
        (incoming.sourceCapabilities
                .intersection(existing.sourceCapabilities)
                .isEmpty ||
            incoming.sourceAppIds.intersection(existing.sourceAppIds).isEmpty);

    if (merchantMatches) reasons.add(DeduplicationReason.sameMerchant);
    if (accountMatches) reasons.add(DeduplicationReason.sameAccount);
    if (crossSource) reasons.add(DeduplicationReason.crossSource);

    final kind = merchantMatches && accountMatches
        ? DeduplicationKind.duplicate
        : (merchantMatches || accountMatches || crossSource)
            ? DeduplicationKind.possibleDuplicate
            : null;
    if (kind == null) return null;

    return DeduplicationDecision(
      kind: kind,
      matchedId: existing.id,
      reasons: reasons,
    );
  }

  String? _normalizedMerchant(String? merchant) {
    final normalized = merchant
        ?.trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_/\\,，.。·]+'), '');
    return (normalized == null || normalized.isEmpty) ? null : normalized;
  }
}
