import 'package:beecount_extension_api/beecount_extension_api.dart';

final class NotificationEventParser implements AutomationEventParser {
  NotificationEventParser({
    required Set<String> supportedSourceAppIds,
    this.parserVersion = 1,
  }) : supportedSourceAppIds = Set<String>.unmodifiable(supportedSourceAppIds);

  @override
  String get id => 'core.notification.v$parserVersion';

  final Set<String> supportedSourceAppIds;
  final int parserVersion;

  @override
  bool supports(CapturedEventSource source) {
    return source.capability == AutomationSourceCapability.notification &&
        supportedSourceAppIds.contains(source.sourceAppId);
  }

  @override
  Future<AutomationParserResult> parse(CapturedAutomationEvent event) async {
    if (!supports(event.source)) {
      return AutomationParserResult(
        event: event,
        disposition: ParserDisposition.ignored,
        safeReasonCode: 'parser.unsupported_source',
      );
    }
    if (event.lifecycle == PlatformEventLifecycle.removed) {
      return AutomationParserResult(
        event: event,
        disposition: ParserDisposition.ignored,
        safeReasonCode: 'parser.removed_event',
      );
    }

    final text = event.textFragments
        .map((fragment) => fragment.value.trim())
        .where((value) => value.isNotEmpty)
        .join('\n');
    if (text.isEmpty) {
      return AutomationParserResult(
        event: event,
        disposition: ParserDisposition.incomplete,
        issues: const <ParserIssueCode>[
          ParserIssueCode.missingAmount,
          ParserIssueCode.missingDirection,
          ParserIssueCode.missingTransactionKind,
        ],
        safeReasonCode: 'parser.empty_text',
      );
    }
    if (_containsAny(text, _marketingKeywords) &&
        !_containsAny(text, _transactionKeywords)) {
      return AutomationParserResult(
        event: event,
        disposition: ParserDisposition.ignored,
        safeReasonCode: 'parser.marketing_notification',
      );
    }

    final amountMatches = _findAmounts(text);
    final distinctAmounts = amountMatches.map((match) => match.minor).toSet();
    final amountMinor =
        distinctAmounts.length == 1 ? distinctAmounts.single : null;
    final semantic = _semanticFor(text);
    final issues = <ParserIssueCode>[
      if (amountMatches.isEmpty) ParserIssueCode.missingAmount,
      if (distinctAmounts.length > 1) ParserIssueCode.ambiguousAmount,
      if (semantic.direction == AutomationDirection.unknown)
        ParserIssueCode.missingDirection,
      if (semantic.kind == AutomationTransactionKind.unknown)
        ParserIssueCode.missingTransactionKind,
    ];
    final source = event.source.toCandidateReference(
      parserVersion: parserVersion,
      lifecycle: event.lifecycle,
      isCurrent: true,
    );
    final evidence = <CandidateEvidence>[
      if (amountMinor != null)
        CandidateEvidence(
          field: CandidateEvidenceField.amount,
          sourceIdentityKey: source.identityKey,
          start: amountMatches.first.start,
          end: amountMatches.first.end,
        ),
      if (amountMinor != null)
        CandidateEvidence(
          field: CandidateEvidenceField.currency,
          sourceIdentityKey: source.identityKey,
          start: amountMatches.first.start,
          end: amountMatches.first.end,
        ),
      if (semantic.direction != AutomationDirection.unknown)
        CandidateEvidence(
          field: CandidateEvidenceField.direction,
          sourceIdentityKey: source.identityKey,
        ),
      if (semantic.kind != AutomationTransactionKind.unknown)
        CandidateEvidence(
          field: CandidateEvidenceField.transactionKind,
          sourceIdentityKey: source.identityKey,
        ),
      CandidateEvidence(
        field: CandidateEvidenceField.occurredAt,
        sourceIdentityKey: source.identityKey,
      ),
    ];
    final candidate = AutomationCandidate(
      id: 'notification:${event.source.sourceAppId}:${event.source.eventIdHash}',
      createdAt: event.capturedAt,
      updatedAt: event.capturedAt,
      occurredAt: event.source.observedAt,
      amountMinor: amountMinor,
      currency: amountMinor == null ? null : 'CNY',
      direction: semantic.direction,
      transactionKind: semantic.kind,
      merchant: _merchantFor(text),
      sources: <SourceEventReference>[source],
      evidence: evidence,
      state: issues.isEmpty
          ? AutomationCandidateState.detected
          : AutomationCandidateState.pending,
      parserVersion: parserVersion,
    );
    return AutomationParserResult(
      event: event,
      disposition: issues.isEmpty
          ? ParserDisposition.candidate
          : ParserDisposition.incomplete,
      issues: issues,
      candidates: <AutomationCandidate>[candidate],
      safeReasonCode: issues.isEmpty ? null : 'parser.required_fields_missing',
    );
  }
}

final class _AmountMatch {
  const _AmountMatch({
    required this.minor,
    required this.start,
    required this.end,
  });

  final int minor;
  final int start;
  final int end;
}

final class _SemanticMatch {
  const _SemanticMatch(this.direction, this.kind);

  final AutomationDirection direction;
  final AutomationTransactionKind kind;
}

List<_AmountMatch> _findAmounts(String text) {
  final matches = <_AmountMatch>[];
  final seenRanges = <String>{};
  for (final pattern in _amountPatterns) {
    for (final match in pattern.allMatches(text)) {
      final rawAmount = match.namedGroup('amount');
      if (rawAmount == null) continue;
      final minor = _minorUnits(rawAmount);
      if (minor == null || minor <= 0) continue;
      final rangeKey = '${match.start}:${match.end}';
      if (!seenRanges.add(rangeKey)) continue;
      matches
          .add(_AmountMatch(minor: minor, start: match.start, end: match.end));
    }
  }
  matches.sort((left, right) => left.start.compareTo(right.start));
  return matches;
}

int? _minorUnits(String raw) {
  final normalized = raw.replaceAll(',', '');
  if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final whole = int.tryParse(parts.first);
  if (whole == null) return null;
  final fraction = switch (parts.length) {
    1 => 0,
    2 when parts[1].length == 1 => int.parse(parts[1]) * 10,
    2 => int.parse(parts[1]),
    _ => null,
  };
  if (fraction == null) return null;
  return whole * 100 + fraction;
}

_SemanticMatch _semanticFor(String text) {
  if (_containsAny(text, const <String>['预授权'])) {
    return const _SemanticMatch(
      AutomationDirection.expense,
      AutomationTransactionKind.preauthorization,
    );
  }
  if (_containsAny(text, const <String>['退款', '已退', '退回'])) {
    final redPacket = text.contains('红包');
    return _SemanticMatch(
      AutomationDirection.refund,
      redPacket
          ? AutomationTransactionKind.redPacketReturned
          : AutomationTransactionKind.refund,
    );
  }
  if (_containsAny(text, const <String>['信用卡还款', '还款成功'])) {
    return const _SemanticMatch(
      AutomationDirection.transfer,
      AutomationTransactionKind.creditCardRepayment,
    );
  }
  if (text.contains('红包')) {
    if (_containsAny(text, const <String>['收到', '领取', '入账'])) {
      return const _SemanticMatch(
        AutomationDirection.income,
        AutomationTransactionKind.redPacketReceived,
      );
    }
    if (_containsAny(text, const <String>['发送', '发出', '支付'])) {
      return const _SemanticMatch(
        AutomationDirection.expense,
        AutomationTransactionKind.redPacketSent,
      );
    }
  }
  if (_containsAny(text, const <String>['手续费', '服务费'])) {
    return const _SemanticMatch(
      AutomationDirection.expense,
      AutomationTransactionKind.fee,
    );
  }
  if (_containsAny(text, const <String>['转账', '转出', '转入'])) {
    return const _SemanticMatch(
      AutomationDirection.transfer,
      AutomationTransactionKind.transfer,
    );
  }
  if (_containsAny(text, const <String>['收款', '到账', '收入', '收钱'])) {
    return const _SemanticMatch(
      AutomationDirection.income,
      AutomationTransactionKind.incomeReceipt,
    );
  }
  if (_containsAny(
      text, const <String>['支付成功', '付款成功', '消费', '扣款', '支出', '已支付'])) {
    return const _SemanticMatch(
      AutomationDirection.expense,
      AutomationTransactionKind.purchase,
    );
  }
  return const _SemanticMatch(
    AutomationDirection.unknown,
    AutomationTransactionKind.unknown,
  );
}

String? _merchantFor(String text) {
  for (final pattern in _merchantPatterns) {
    final match = pattern.firstMatch(text);
    final raw = match?.namedGroup('merchant')?.trim();
    if (raw == null || raw.length < 2) continue;
    return raw.length <= 80 ? raw : raw.substring(0, 80);
  }
  return null;
}

bool _containsAny(String text, List<String> values) {
  return values.any(text.contains);
}

final List<RegExp> _amountPatterns = <RegExp>[
  RegExp(r'(?:¥|￥|人民币|RMB|CNY)\s*(?<amount>\d{1,9}(?:,\d{3})*(?:\.\d{1,2})?)',
      caseSensitive: false),
  RegExp(r'(?<amount>\d{1,9}(?:,\d{3})*(?:\.\d{1,2})?)\s*元'),
];

final List<RegExp> _merchantPatterns = <RegExp>[
  RegExp(r'(?:商户|付款给|支付给)[：:\s]*(?<merchant>[^\n，,。]{2,80})'),
  RegExp(r'在[「“]?(?<merchant>[^\n，,。”」]{2,40})[」”]?(?:消费|支付)'),
];

const List<String> _transactionKeywords = <String>[
  '支付成功',
  '付款成功',
  '消费',
  '扣款',
  '支出',
  '已支付',
  '收款',
  '到账',
  '收入',
  '退款',
  '转账',
  '还款成功',
  '红包',
  '手续费',
  '预授权',
];

const List<String> _marketingKeywords = <String>[
  '优惠券',
  '立减',
  '抽奖',
  '活动',
  '广告',
  '抢购',
  '促销',
];
