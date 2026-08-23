import 'package:beecount_automation_core/beecount_automation_core.dart';
import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:test/test.dart';

void main() {
  final parser = NotificationEventParser(
    supportedSourceAppIds: const <String>{'wechat', 'alipay'},
  );

  test('parses an evidence-backed purchase and keeps replay ID stable',
      () async {
    final event = notificationEvent(
      fragments: const <CapturedTextFragment>[
        CapturedTextFragment(
          role: CapturedTextRole.title,
          value: '微信支付',
        ),
        CapturedTextFragment(
          role: CapturedTextRole.body,
          value: '支付成功 ￥12.80\n商户：示例便利店',
        ),
      ],
    );

    final first = await parser.parse(event);
    final replay = await parser.parse(event);

    expect(first.disposition, ParserDisposition.candidate);
    expect(first.candidates.single.amountMinor, 1280);
    expect(first.candidates.single.currency, 'CNY');
    expect(first.candidates.single.direction, AutomationDirection.expense);
    expect(
      first.candidates.single.transactionKind,
      AutomationTransactionKind.purchase,
    );
    expect(first.candidates.single.merchant, '示例便利店');
    expect(replay.candidates.single.id, first.candidates.single.id);
  });

  test('marketing content without a transaction signal is ignored', () async {
    final result = await parser.parse(
      notificationEvent(text: '限时活动：领取优惠券，参与抽奖'),
    );

    expect(result.disposition, ParserDisposition.ignored);
    expect(result.candidates, isEmpty);
    expect(result.safeReasonCode, 'parser.marketing_notification');
  });

  test('multiple different amounts wait for confirmation', () async {
    final result = await parser.parse(
      notificationEvent(text: '消费￥12.80，优惠后￥10.00'),
    );

    expect(result.disposition, ParserDisposition.incomplete);
    expect(result.issues, contains(ParserIssueCode.ambiguousAmount));
    expect(result.candidates.single.amountMinor, isNull);
    expect(result.candidates.single.state, AutomationCandidateState.pending);
  });

  test('refund is not treated as ordinary income', () async {
    final result = await parser.parse(
      notificationEvent(text: '退款到账 18.50元'),
    );

    expect(result.disposition, ParserDisposition.candidate);
    expect(result.candidates.single.direction, AutomationDirection.refund);
    expect(
      result.candidates.single.transactionKind,
      AutomationTransactionKind.refund,
    );
  });

  test('removed events and unsupported apps are ignored', () async {
    final removed = await parser.parse(
      notificationEvent(
        lifecycle: PlatformEventLifecycle.removed,
        fragments: const <CapturedTextFragment>[],
      ),
    );
    final unsupported = await parser.parse(
      notificationEvent(sourceAppId: 'bank.example'),
    );

    expect(removed.disposition, ParserDisposition.ignored);
    expect(removed.safeReasonCode, 'parser.removed_event');
    expect(unsupported.disposition, ParserDisposition.ignored);
    expect(unsupported.safeReasonCode, 'parser.unsupported_source');
  });

  test('empty redacted notification stays pending without inventing data',
      () async {
    final result = await parser.parse(
      notificationEvent(fragments: const <CapturedTextFragment>[]),
    );

    expect(result.disposition, ParserDisposition.incomplete);
    expect(result.candidates, isEmpty);
    expect(result.issues, contains(ParserIssueCode.missingAmount));
    expect(result.safeReasonCode, 'parser.empty_text');
  });
}

CapturedAutomationEvent notificationEvent({
  String sourceAppId = 'wechat',
  String text = '支付成功 ￥12.80',
  PlatformEventLifecycle lifecycle = PlatformEventLifecycle.posted,
  List<CapturedTextFragment>? fragments,
}) {
  final time = DateTime.utc(2026, 8, 24, 10);
  return CapturedAutomationEvent(
    id: 'capture-1',
    source: CapturedEventSource(
      capability: AutomationSourceCapability.notification,
      sourceAppId: sourceAppId,
      packageName: 'example.package',
      eventId: 'platform-event-1',
      eventIdHash: 'hmac-sha256:event_1',
      observedAt: time,
    ),
    lifecycle: lifecycle,
    capturedAt: time,
    textFragments: fragments ??
        <CapturedTextFragment>[
          CapturedTextFragment(role: CapturedTextRole.body, value: text),
        ],
  );
}
