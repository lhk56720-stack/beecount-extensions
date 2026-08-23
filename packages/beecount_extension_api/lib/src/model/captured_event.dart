import 'automation_candidate.dart';

/// Non-content identity metadata used to reject disabled or unsupported
/// sources before their text is copied into Dart memory.
final class CapturedEventSource {
  const CapturedEventSource({
    required this.capability,
    required this.sourceAppId,
    required this.eventId,
    required this.eventIdHash,
    required this.observedAt,
    this.packageName,
    this.supersedesEventId,
    this.supersedesEventIdHash,
  });

  final AutomationSourceCapability capability;
  final String sourceAppId;
  final String? packageName;

  /// Raw platform event ID. Memory-only or encrypted recovery payload only.
  final String eventId;
  final String eventIdHash;

  /// Raw superseded ID. Memory-only or encrypted recovery payload only.
  final String? supersedesEventId;
  final String? supersedesEventIdHash;
  final DateTime observedAt;

  String get identityKey => '${capability.name}:$sourceAppId:$eventIdHash';

  SourceEventReference toCandidateReference({
    required int parserVersion,
    required PlatformEventLifecycle lifecycle,
    required bool isCurrent,
  }) {
    return SourceEventReference(
      capability: capability,
      sourceAppId: sourceAppId,
      packageName: packageName,
      eventIdHash: eventIdHash,
      supersedesEventIdHash: supersedesEventIdHash,
      lifecycle: lifecycle,
      isCurrent: isCurrent,
      observedAt: observedAt,
      parserVersion: parserVersion,
    );
  }
}

enum CapturedTextRole {
  title,
  body,
  sender,
  paymentPageText,
}

/// Sensitive text captured from one enabled source.
///
/// This type intentionally has no JSON serialization API. It is memory-only
/// unless an approved platform recovery queue encrypts the complete payload.
final class CapturedTextFragment {
  const CapturedTextFragment({
    required this.role,
    required this.value,
  });

  final CapturedTextRole role;
  final String value;
}

final class CapturedAutomationEvent {
  CapturedAutomationEvent({
    required this.id,
    required this.source,
    required this.lifecycle,
    required this.capturedAt,
    required List<CapturedTextFragment> textFragments,
  }) : textFragments = List<CapturedTextFragment>.unmodifiable(textFragments) {
    if (id.isEmpty || source.eventId.isEmpty) {
      throw ArgumentError(
        'capture ID and raw event ID must not be empty',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(source.sourceAppId)) {
      throw ArgumentError.value(
        source.sourceAppId,
        'source.sourceAppId',
        'must be a stable non-sensitive app ID',
      );
    }
    _validateHmacToken(source.eventIdHash, 'source.eventIdHash');
    _validateHmacToken(
      source.supersedesEventIdHash,
      'source.supersedesEventIdHash',
      nullable: true,
    );
    if ((source.supersedesEventId == null) !=
        (source.supersedesEventIdHash == null)) {
      throw ArgumentError(
        'superseded raw event ID and its HMAC must both be present or absent',
      );
    }
    if (source.packageName != null && source.packageName!.isEmpty) {
      throw ArgumentError.value(
        source.packageName,
        'source.packageName',
        'must be null or non-empty',
      );
    }
    if (lifecycle == PlatformEventLifecycle.removed &&
        this.textFragments.isNotEmpty) {
      throw ArgumentError.value(
        textFragments,
        'textFragments',
        'must be empty for a removed event',
      );
    }
  }

  /// Queue capture ID. It is distinct from raw event ID and source HMAC.
  final String id;
  final CapturedEventSource source;
  final PlatformEventLifecycle lifecycle;
  final DateTime capturedAt;
  final List<CapturedTextFragment> textFragments;

  static const int currentPayloadSchemaVersion = 1;

  bool get hasText => textFragments.any((item) => item.value.trim().isNotEmpty);

  bool get isParseable =>
      lifecycle != PlatformEventLifecycle.removed && hasText;
}

enum ParserDisposition {
  ignored,
  candidate,
  incomplete,
  retryableFailure,
  permanentFailure,
}

enum ParserIssueCode {
  missingAmount,
  ambiguousAmount,
  missingCurrency,
  invalidCurrency,
  missingDirection,
  conflictingDirection,
  missingTransactionKind,
  conflictingTransactionKind,
  missingOccurredAt,
  unsupportedTemplate,
  incompleteRelationship,
}

final class AutomationParserResult {
  AutomationParserResult({
    required CapturedAutomationEvent event,
    required this.disposition,
    List<ParserIssueCode> issues = const <ParserIssueCode>[],
    List<AutomationCandidate> candidates = const <AutomationCandidate>[],
    this.safeReasonCode,
  })  : issues = List<ParserIssueCode>.unmodifiable(issues),
        candidates = List<AutomationCandidate>.unmodifiable(candidates) {
    if (safeReasonCode != null &&
        !RegExp(r'^[a-z0-9_.-]{1,80}$').hasMatch(safeReasonCode!)) {
      throw ArgumentError.value(
        safeReasonCode,
        'safeReasonCode',
        'must be a short non-sensitive machine code',
      );
    }
    if (event.lifecycle == PlatformEventLifecycle.removed &&
        disposition != ParserDisposition.ignored) {
      throw ArgumentError.value(
        disposition,
        'disposition',
        'removed events must be ignored',
      );
    }
    if (disposition == ParserDisposition.candidate && candidates.isEmpty) {
      throw ArgumentError.value(
        candidates,
        'candidates',
        'must not be empty when disposition is candidate',
      );
    }
    if (candidates.isNotEmpty &&
        disposition != ParserDisposition.candidate &&
        disposition != ParserDisposition.incomplete) {
      throw ArgumentError.value(
        candidates,
        'candidates',
        'are only valid for candidate or incomplete dispositions',
      );
    }
    for (final candidate in candidates) {
      final stateAllowed =
          candidate.state == AutomationCandidateState.detected ||
              candidate.state == AutomationCandidateState.pending;
      if (!stateAllowed) {
        throw ArgumentError.value(
          candidate.state,
          'candidates.state',
          'parser candidates must be detected or pending',
        );
      }
      final containsInputSource = candidate.sources.any(
        (source) =>
            source.identityKey == event.source.identityKey &&
            source.lifecycle == event.lifecycle,
      );
      if (!containsInputSource) {
        throw ArgumentError.value(
          candidate.id,
          'candidates.sources',
          'each parser candidate must reference the input event',
        );
      }
    }
  }

  final ParserDisposition disposition;
  final List<ParserIssueCode> issues;
  final List<AutomationCandidate> candidates;
  final String? safeReasonCode;
}

abstract interface class AutomationEventParser {
  String get id;

  /// Must be called before the collector materializes sensitive text.
  bool supports(CapturedEventSource source);

  /// Replaying the same source identity must produce the same candidate ID.
  /// Updated source events must update or explicitly supersede that candidate.
  Future<AutomationParserResult> parse(CapturedAutomationEvent event);
}

void _validateHmacToken(
  String? value,
  String field, {
  bool nullable = false,
}) {
  if (value == null && nullable) return;
  if (value == null ||
      !RegExp(r'^hmac-sha256:[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw ArgumentError.value(value, field, 'must be an hmac-sha256 token');
  }
}
