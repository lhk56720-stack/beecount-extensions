import 'package:beecount_extension_api/beecount_extension_api.dart';

final class AutomationDiagnosticEvent {
  const AutomationDiagnosticEvent({
    required this.occurredAt,
    required this.code,
    this.sourceAppId,
  });

  final DateTime occurredAt;
  final String code;
  final String? sourceAppId;

  factory AutomationDiagnosticEvent.fromJson(Map<String, Object?> json) {
    final code = json['code'];
    final occurredAt = json['occurredAt'];
    final sourceAppId = json['sourceAppId'];
    if (code is! String ||
        !RegExp(r'^[a-z0-9_.-]{1,80}$').hasMatch(code) ||
        occurredAt is! String ||
        (sourceAppId != null &&
            (sourceAppId is! String ||
                !RegExp(r'^[a-z0-9_.-]{1,40}$').hasMatch(sourceAppId)))) {
      throw const FormatException('invalid automation diagnostic event');
    }
    return AutomationDiagnosticEvent(
      occurredAt: DateTime.parse(occurredAt).toUtc(),
      code: code,
      sourceAppId: sourceAppId as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'code': code,
        if (sourceAppId != null) 'sourceAppId': sourceAppId,
      };
}

final class AutomationSettings {
  AutomationSettings({
    required this.automationEnabled,
    required this.notificationEnabled,
    required this.autoPostEnabled,
    required Set<String> enabledSourceAppIds,
    required Map<String, String> sourceAccountIds,
    this.targetLedgerId,
  })  : enabledSourceAppIds = Set<String>.unmodifiable(enabledSourceAppIds),
        sourceAccountIds = Map<String, String>.unmodifiable(sourceAccountIds);

  factory AutomationSettings.defaults() => AutomationSettings(
        automationEnabled: false,
        notificationEnabled: false,
        autoPostEnabled: false,
        enabledSourceAppIds: const <String>{},
        sourceAccountIds: const <String, String>{},
      );

  final bool automationEnabled;
  final bool notificationEnabled;
  final bool autoPostEnabled;
  final Set<String> enabledSourceAppIds;
  final String? targetLedgerId;
  final Map<String, String> sourceAccountIds;

  AutomationSettings copyWith({
    bool? automationEnabled,
    bool? notificationEnabled,
    bool? autoPostEnabled,
    Set<String>? enabledSourceAppIds,
    String? targetLedgerId,
    bool clearTargetLedger = false,
    Map<String, String>? sourceAccountIds,
  }) {
    return AutomationSettings(
      automationEnabled: automationEnabled ?? this.automationEnabled,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      autoPostEnabled: autoPostEnabled ?? this.autoPostEnabled,
      enabledSourceAppIds: enabledSourceAppIds ?? this.enabledSourceAppIds,
      targetLedgerId:
          clearTargetLedger ? null : targetLedgerId ?? this.targetLedgerId,
      sourceAccountIds: sourceAccountIds ?? this.sourceAccountIds,
    );
  }

  factory AutomationSettings.fromJson(Map<String, Object?> json) {
    final sources = json['enabledSourceAppIds'];
    final accounts = json['sourceAccountIds'];
    if (sources is! List || accounts is! Map) {
      throw const FormatException('invalid automation settings');
    }
    return AutomationSettings(
      automationEnabled: json['automationEnabled'] == true,
      notificationEnabled: json['notificationEnabled'] == true,
      autoPostEnabled: json['autoPostEnabled'] == true,
      enabledSourceAppIds: sources.cast<String>().toSet(),
      targetLedgerId: json['targetLedgerId'] as String?,
      sourceAccountIds: Map<String, String>.from(accounts),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'automationEnabled': automationEnabled,
        'notificationEnabled': notificationEnabled,
        'autoPostEnabled': autoPostEnabled,
        'enabledSourceAppIds': enabledSourceAppIds.toList(growable: false),
        'targetLedgerId': targetLedgerId,
        'sourceAccountIds': sourceAccountIds,
      };
}

final class AutomationBundleState {
  AutomationBundleState({
    required this.settings,
    required List<AutomationCandidate> candidates,
    required Map<String, String> postedTransactionIds,
    List<AutomationDiagnosticEvent> diagnostics =
        const <AutomationDiagnosticEvent>[],
  })  : candidates = List<AutomationCandidate>.unmodifiable(candidates),
        postedTransactionIds =
            Map<String, String>.unmodifiable(postedTransactionIds),
        diagnostics = List<AutomationDiagnosticEvent>.unmodifiable(diagnostics);

  factory AutomationBundleState.defaults() => AutomationBundleState(
        settings: AutomationSettings.defaults(),
        candidates: const <AutomationCandidate>[],
        postedTransactionIds: const <String, String>{},
        diagnostics: const <AutomationDiagnosticEvent>[],
      );

  final AutomationSettings settings;
  final List<AutomationCandidate> candidates;
  final Map<String, String> postedTransactionIds;
  final List<AutomationDiagnosticEvent> diagnostics;

  factory AutomationBundleState.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('unsupported bundle state schema');
    }
    final rawCandidates = json['candidates'];
    final rawReceipts = json['postedTransactionIds'];
    final rawDiagnostics = json['diagnostics'];
    if (rawCandidates is! List || rawReceipts is! Map) {
      throw const FormatException('invalid bundle state');
    }
    return AutomationBundleState(
      settings: AutomationSettings.fromJson(
        Map<String, Object?>.from(json['settings'] as Map),
      ),
      candidates: rawCandidates
          .map(
            (item) => AutomationCandidate.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(growable: false),
      postedTransactionIds: Map<String, String>.from(rawReceipts),
      diagnostics: rawDiagnostics == null
          ? const <AutomationDiagnosticEvent>[]
          : (rawDiagnostics as List)
              .map(
                (item) => AutomationDiagnosticEvent.fromJson(
                  Map<String, Object?>.from(item as Map),
                ),
              )
              .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': 1,
        'settings': settings.toJson(),
        'candidates': candidates.map((item) => item.toJson()).toList(),
        'postedTransactionIds': postedTransactionIds,
        'diagnostics': diagnostics.map((item) => item.toJson()).toList(),
      };
}
