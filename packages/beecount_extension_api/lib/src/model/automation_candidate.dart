enum AutomationDirection {
  unknown,
  expense,
  income,
  transfer,
  refund,
}

/// Business meaning of a candidate, independent from its accounting direction.
///
/// For example, both a normal purchase and a service fee are expenses, while a
/// credit-card repayment and a wallet transfer are transfers. Core owns the
/// mapping and decides whether the relationship is complete enough to post.
enum AutomationTransactionKind {
  unknown,
  purchase,
  incomeReceipt,
  refund,
  transfer,
  creditCardRepayment,
  redPacketSent,
  redPacketReceived,
  redPacketReturned,
  fee,
  preauthorization,
}

enum AutomationCandidateState {
  detected,
  pending,
  autoPosted,
  confirmed,
  ignored,
  duplicate,
  expired,
  correctionPending,
  undone,
  error,
}

enum AutomationSourceCapability {
  notification,
  accessibility,
  sms,
  screenshot,
  imageShare,
  billImport,
  manual,
}

enum PlatformEventLifecycle {
  posted,
  updated,
  removed,
  snapshotChanged,
}

enum CandidateEvidenceField {
  amount,
  currency,
  direction,
  transactionKind,
  merchant,
  account,
  toAccount,
  occurredAt,
  stableTransactionId,
  relationship,
}

final class SourceEventReference {
  const SourceEventReference({
    required this.capability,
    required this.sourceAppId,
    required this.eventIdHash,
    required this.lifecycle,
    required this.isCurrent,
    required this.observedAt,
    required this.parserVersion,
    this.packageName,
    this.supersedesEventIdHash,
  });

  final AutomationSourceCapability capability;
  final String sourceAppId;
  final String? packageName;
  final String eventIdHash;
  final String? supersedesEventIdHash;
  final PlatformEventLifecycle lifecycle;
  final bool isCurrent;
  final DateTime observedAt;
  final int parserVersion;

  String get identityKey => '${capability.name}:$sourceAppId:$eventIdHash';

  factory SourceEventReference.fromJson(Map<String, Object?> json) {
    return SourceEventReference(
      capability: AutomationSourceCapability.values.byName(
        _requiredString(json, 'capability'),
      ),
      sourceAppId: _requiredString(json, 'sourceAppId'),
      packageName: _optionalString(json, 'packageName'),
      eventIdHash: _requiredString(json, 'eventIdHash'),
      supersedesEventIdHash: _optionalString(json, 'supersedesEventIdHash'),
      lifecycle: PlatformEventLifecycle.values.byName(
        _requiredString(json, 'lifecycle'),
      ),
      isCurrent: _requiredBool(json, 'isCurrent'),
      observedAt: _requiredDateTime(json, 'observedAt'),
      parserVersion: _requiredInt(json, 'parserVersion'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'capability': capability.name,
        'sourceAppId': sourceAppId,
        'packageName': packageName,
        'eventIdHash': eventIdHash,
        'supersedesEventIdHash': supersedesEventIdHash,
        'lifecycle': lifecycle.name,
        'isCurrent': isCurrent,
        'observedAt': observedAt.toUtc().toIso8601String(),
        'parserVersion': parserVersion,
      };
}

final class CandidateEvidence {
  const CandidateEvidence({
    required this.field,
    required this.sourceIdentityKey,
    this.start,
    this.end,
  });

  final CandidateEvidenceField field;
  final String sourceIdentityKey;
  final int? start;
  final int? end;

  factory CandidateEvidence.fromJson(Map<String, Object?> json) {
    return CandidateEvidence(
      field: CandidateEvidenceField.values.byName(
        _requiredString(json, 'field'),
      ),
      sourceIdentityKey: _requiredString(json, 'sourceIdentityKey'),
      start: json['start'] as int?,
      end: json['end'] as int?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'field': field.name,
        'sourceIdentityKey': sourceIdentityKey,
        'start': start,
        'end': end,
      };
}

final class AutomationCandidate {
  AutomationCandidate({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.occurredAt,
    required this.amountMinor,
    required this.currency,
    required this.direction,
    required this.transactionKind,
    required List<SourceEventReference> sources,
    required List<CandidateEvidence> evidence,
    required this.state,
    required this.parserVersion,
    this.targetLedgerId,
    this.merchant,
    this.note,
    this.accountHintToken,
    this.resolvedAccountId,
    this.resolvedToAccountId,
    this.resolvedCategoryId,
    this.categoryHint,
    this.relatedTransactionId,
    this.stableTransactionIdHash,
    this.parserConfidence,
  })  : sources = List<SourceEventReference>.unmodifiable(sources),
        evidence = List<CandidateEvidence>.unmodifiable(evidence) {
    _validateCandidate(this);
  }

  static const int currentSchemaVersion = 1;

  final String id;
  final String? targetLedgerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime occurredAt;
  final int? amountMinor;
  final String? currency;
  final AutomationDirection direction;
  final AutomationTransactionKind transactionKind;
  final String? merchant;
  final String? note;
  final String? accountHintToken;
  final String? resolvedAccountId;
  final String? resolvedToAccountId;
  final String? resolvedCategoryId;
  final String? categoryHint;
  final String? relatedTransactionId;
  final String? stableTransactionIdHash;
  final List<SourceEventReference> sources;
  final List<CandidateEvidence> evidence;
  final double? parserConfidence;
  final AutomationCandidateState state;
  final int parserVersion;

  bool hasEvidence(
    CandidateEvidenceField field, {
    Set<String>? sourceIdentityKeys,
  }) {
    return evidence.any(
      (item) =>
          item.field == field &&
          (sourceIdentityKeys == null ||
              sourceIdentityKeys.contains(item.sourceIdentityKey)),
    );
  }

  AutomationCandidate withState(
    AutomationCandidateState nextState,
    DateTime changedAt,
  ) {
    return AutomationCandidate(
      id: id,
      targetLedgerId: targetLedgerId,
      createdAt: createdAt,
      updatedAt: changedAt,
      occurredAt: occurredAt,
      amountMinor: amountMinor,
      currency: currency,
      direction: direction,
      transactionKind: transactionKind,
      merchant: merchant,
      note: note,
      accountHintToken: accountHintToken,
      resolvedAccountId: resolvedAccountId,
      resolvedToAccountId: resolvedToAccountId,
      resolvedCategoryId: resolvedCategoryId,
      categoryHint: categoryHint,
      relatedTransactionId: relatedTransactionId,
      stableTransactionIdHash: stableTransactionIdHash,
      sources: sources,
      evidence: evidence,
      parserConfidence: parserConfidence,
      state: nextState,
      parserVersion: parserVersion,
    );
  }

  factory AutomationCandidate.fromJson(Map<String, Object?> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != currentSchemaVersion) {
      throw FormatException('Unsupported candidate schema: $schemaVersion');
    }

    final rawSources = json['sources'];
    final rawEvidence = json['evidence'];
    if (rawSources is! List || rawEvidence is! List) {
      throw const FormatException('sources and evidence must be arrays');
    }

    return AutomationCandidate(
      id: _requiredString(json, 'id'),
      targetLedgerId: _optionalString(json, 'targetLedgerId'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      occurredAt: _requiredDateTime(json, 'occurredAt'),
      amountMinor: json['amountMinor'] as int?,
      currency: _optionalString(json, 'currency'),
      direction: AutomationDirection.values.byName(
        _requiredString(json, 'direction'),
      ),
      transactionKind: AutomationTransactionKind.values.byName(
        _requiredString(json, 'transactionKind'),
      ),
      merchant: _optionalString(json, 'merchant'),
      note: _optionalString(json, 'note'),
      accountHintToken: _optionalString(json, 'accountHintToken'),
      resolvedAccountId: _optionalString(json, 'resolvedAccountId'),
      resolvedToAccountId: _optionalString(json, 'resolvedToAccountId'),
      resolvedCategoryId: _optionalString(json, 'resolvedCategoryId'),
      categoryHint: _optionalString(json, 'categoryHint'),
      relatedTransactionId: _optionalString(json, 'relatedTransactionId'),
      stableTransactionIdHash:
          _optionalString(json, 'stableTransactionIdHash'),
      sources: rawSources
          .map((item) => SourceEventReference.fromJson(
                Map<String, Object?>.from(item as Map),
              ))
          .toList(growable: false),
      evidence: rawEvidence
          .map((item) => CandidateEvidence.fromJson(
                Map<String, Object?>.from(item as Map),
              ))
          .toList(growable: false),
      parserConfidence: (json['parserConfidence'] as num?)?.toDouble(),
      state: AutomationCandidateState.values.byName(
        _requiredString(json, 'state'),
      ),
      parserVersion: _requiredInt(json, 'parserVersion'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': currentSchemaVersion,
        'id': id,
        'targetLedgerId': targetLedgerId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'amountMinor': amountMinor,
        'currency': currency,
        'direction': direction.name,
        'transactionKind': transactionKind.name,
        'merchant': merchant,
        'note': note,
        'accountHintToken': accountHintToken,
        'resolvedAccountId': resolvedAccountId,
        'resolvedToAccountId': resolvedToAccountId,
        'resolvedCategoryId': resolvedCategoryId,
        'categoryHint': categoryHint,
        'relatedTransactionId': relatedTransactionId,
        'stableTransactionIdHash': stableTransactionIdHash,
        'sources': sources.map((item) => item.toJson()).toList(),
        'evidence': evidence.map((item) => item.toJson()).toList(),
        'parserConfidence': parserConfidence,
        'state': state.name,
        'parserVersion': parserVersion,
      };
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be null or a non-empty string');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer');
  return value;
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean');
  return value;
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key must be an ISO date-time');
  return parsed;
}

void _validateCandidate(AutomationCandidate candidate) {
  if (candidate.id.isEmpty) {
    throw ArgumentError.value(candidate.id, 'id', 'must not be empty');
  }
  if (candidate.parserVersion < 1) {
    throw ArgumentError.value(
      candidate.parserVersion,
      'parserVersion',
      'must be at least 1',
    );
  }
  if (candidate.amountMinor != null && candidate.amountMinor! < 1) {
    throw ArgumentError.value(
      candidate.amountMinor,
      'amountMinor',
      'must be null or a positive minor-unit amount',
    );
  }
  final currency = candidate.currency;
  if (currency != null && !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
    throw ArgumentError.value(
      currency,
      'currency',
      'must be null or an ISO 4217 uppercase code',
    );
  }
  if (candidate.parserConfidence != null &&
      (candidate.parserConfidence! < 0 || candidate.parserConfidence! > 1)) {
    throw ArgumentError.value(
      candidate.parserConfidence,
      'parserConfidence',
      'must be between 0 and 1',
    );
  }
  if (candidate.sources.isEmpty) {
    throw ArgumentError.value(
      candidate.sources,
      'sources',
      'must contain at least one source',
    );
  }

  final sourcesByIdentityKey = <String, SourceEventReference>{};
  for (final source in candidate.sources) {
    if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(source.sourceAppId)) {
      throw ArgumentError.value(
        source.sourceAppId,
        'sources.sourceAppId',
        'must be a stable non-sensitive app ID',
      );
    }
    _validateHmacToken(source.eventIdHash, 'sources.eventIdHash');
    _validateHmacToken(
      source.supersedesEventIdHash,
      'sources.supersedesEventIdHash',
    );
    if (source.parserVersion < 1) {
      throw ArgumentError.value(
        source.parserVersion,
        'sources.parserVersion',
        'must be at least 1',
      );
    }
    _validateOptionalText(source.packageName, 'sources.packageName');
    _validateOptionalText(
      source.supersedesEventIdHash,
      'sources.supersedesEventIdHash',
    );
    if (sourcesByIdentityKey.containsKey(source.identityKey)) {
      throw ArgumentError.value(
        source.identityKey,
        'sources',
        'source identities must be unique',
      );
    }
    sourcesByIdentityKey[source.identityKey] = source;
  }

  final currentSources = candidate.sources.where(
    (source) =>
        source.isCurrent &&
        source.lifecycle != PlatformEventLifecycle.removed,
  );
  if (currentSources.isEmpty) {
    throw ArgumentError.value(
      candidate.sources,
      'sources',
      'must contain at least one current non-removed source',
    );
  }

  final supersededIdentityKeys = <String>{};
  for (final source in candidate.sources) {
    if (source.lifecycle == PlatformEventLifecycle.removed &&
        source.isCurrent) {
      throw ArgumentError.value(
        source.identityKey,
        'sources.isCurrent',
        'a removed source cannot be current',
      );
    }
    final supersededHash = source.supersedesEventIdHash;
    if (supersededHash == null) continue;
    final supersededIdentityKey =
        '${source.capability.name}:${source.sourceAppId}:$supersededHash';
    final supersededSource = sourcesByIdentityKey[supersededIdentityKey];
    if (supersededSource == null ||
        supersededSource.isCurrent ||
        supersededSource.identityKey == source.identityKey) {
      throw ArgumentError.value(
        supersededHash,
        'sources.supersedesEventIdHash',
        'must reference a distinct non-current source in the candidate',
      );
    }
    supersededIdentityKeys.add(supersededIdentityKey);
  }

  for (final source in candidate.sources) {
    if (!source.isCurrent &&
        source.lifecycle != PlatformEventLifecycle.removed &&
        !supersededIdentityKeys.contains(source.identityKey)) {
      throw ArgumentError.value(
        source.identityKey,
        'sources.isCurrent',
        'historical source must be superseded by another source',
      );
    }
  }

  for (final item in candidate.evidence) {
    final source = sourcesByIdentityKey[item.sourceIdentityKey];
    if (source == null) {
      throw ArgumentError.value(
        item.sourceIdentityKey,
        'evidence.sourceIdentityKey',
        'must reference one of the candidate sources',
      );
    }
    if (!source.isCurrent ||
        source.lifecycle == PlatformEventLifecycle.removed) {
      throw ArgumentError.value(
        item.sourceIdentityKey,
        'evidence.sourceIdentityKey',
        'must reference a current non-removed source',
      );
    }
    final hasStart = item.start != null;
    final hasEnd = item.end != null;
    if (hasStart != hasEnd ||
        (hasStart && (item.start! < 0 || item.end! < item.start!))) {
      throw ArgumentError.value(
        '${item.start}:${item.end}',
        'evidence offsets',
        'must both be null or form a non-negative ordered range',
      );
    }
  }

  _validateOptionalText(candidate.targetLedgerId, 'targetLedgerId');
  _validateOptionalText(candidate.resolvedAccountId, 'resolvedAccountId');
  _validateOptionalText(candidate.resolvedToAccountId, 'resolvedToAccountId');
  _validateOptionalText(candidate.resolvedCategoryId, 'resolvedCategoryId');
  _validateOptionalText(candidate.relatedTransactionId, 'relatedTransactionId');
  _validateHmacToken(candidate.accountHintToken, 'accountHintToken');
  _validateHmacToken(
    candidate.stableTransactionIdHash,
    'stableTransactionIdHash',
  );
  _validateBoundedText(candidate.merchant, 'merchant', 80);
  _validateBoundedText(candidate.note, 'note', 120);
  _validateBoundedText(candidate.categoryHint, 'categoryHint', 40);
}

void _validateHmacToken(String? value, String field) {
  if (value == null) return;
  if (!RegExp(r'^hmac-sha256:[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw ArgumentError.value(
      value,
      field,
      'must be an hmac-sha256 token',
    );
  }
}

void _validateOptionalText(String? value, String field) {
  if (value != null && value.isEmpty) {
    throw ArgumentError.value(value, field, 'must be null or non-empty');
  }
}

void _validateBoundedText(
  String? value,
  String field,
  int maxLength,
) {
  if (value == null) return;
  if (value.isEmpty || value.length > maxLength) {
    throw ArgumentError.value(
      value,
      field,
      'must contain at most $maxLength characters',
    );
  }
}
