import 'package:beecount_automation_android/beecount_automation_android.dart';
import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'dev.beecount.extensions/notification_automation.test',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('configuration rejects packages outside the reviewed registry', () {
    expect(
      () => NotificationCaptureConfiguration(
        automationEnabled: true,
        notificationEnabled: true,
        enabledPackageNames: <String>{'example.unreviewed.payment'},
      ),
      throwsArgumentError,
    );
  });

  test('status keeps user preference separate from permission state', () async {
    await messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getStatus');
      return <String, Object?>{
        'platformSupported': true,
        'accessGranted': false,
        'serviceConnected': false,
        'automationEnabled': true,
        'notificationEnabled': true,
        'pendingEventCount': 2,
        'enabledPackageNames': <String>['com.tencent.mm'],
      };
    });

    final status =
        await NotificationAutomationPlatform(channel: channel).getStatus();

    expect(status.automationEnabled, isTrue);
    expect(status.accessGranted, isFalse);
    expect(status.isOperational, isFalse);
    expect(status.pendingEventCount, 2);
  });

  test('lease decodes minimized notification event without losing raw expiry',
      () async {
    final firstEnqueuedAt = DateTime.utc(2026, 8, 24, 10);
    final rawExpiresAt = firstEnqueuedAt.add(const Duration(hours: 24));
    await messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'leaseEvents');
      return <String, Object?>{
        'token': 'lease-1',
        'expiresAtMs': firstEnqueuedAt
            .add(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
        'events': <Object?>[
          <String, Object?>{
            'firstEnqueuedAtMs': firstEnqueuedAt.millisecondsSinceEpoch,
            'rawExpiresAtMs': rawExpiresAt.millisecondsSinceEpoch,
            'attemptCount': 1,
            'event': <String, Object?>{
              'id': 'capture-1',
              'lifecycle': 'posted',
              'capturedAtMs': firstEnqueuedAt.millisecondsSinceEpoch,
              'source': <String, Object?>{
                'sourceAppId': 'wechat',
                'packageName': 'com.tencent.mm',
                'eventId': 'raw-memory-only-event',
                'eventIdHash': 'hmac-sha256:event_token',
                'observedAtMs': firstEnqueuedAt.millisecondsSinceEpoch,
              },
              'textFragments': <Object?>[
                <String, Object?>{
                  'role': 'body',
                  'value': '支付成功 ¥12.80',
                },
              ],
            },
          },
        ],
      };
    });

    final lease = await NotificationAutomationPlatform(channel: channel).lease(
      limit: 10,
      leaseDuration: const Duration(minutes: 1),
    );

    expect(lease.events, hasLength(1));
    expect(lease.events.single.rawExpiresAt, rawExpiresAt);
    expect(lease.events.single.event.source.sourceAppId, 'wechat');
    expect(lease.events.single.event.textFragments.single.value, '支付成功 ¥12.80');
  });

  test('retryable platform failure requires an explicit retry time', () async {
    final platform = NotificationAutomationPlatform(channel: channel);
    await expectLater(
      platform.fail(
        leaseToken: 'lease-1',
        captureId: 'capture-1',
        disposition: PlatformEventFailureDisposition.retryable,
        safeReasonCode: 'parser.retry',
      ),
      throwsArgumentError,
    );
  });

  test('encrypted local state bridge keeps structured values', () async {
    await messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readLocalState');
      return <String, Object?>{
        'schemaVersion': 1,
        'settings': <String, Object?>{'automationEnabled': false},
        'candidates': <Object?>[],
      };
    });

    final state =
        await NotificationAutomationPlatform(channel: channel).readLocalState();

    expect(state?['schemaVersion'], 1);
    expect(state?['candidates'], isEmpty);
  });
}
