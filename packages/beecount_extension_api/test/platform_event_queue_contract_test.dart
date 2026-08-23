import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:test/test.dart';

void main() {
  CapturedAutomationEvent event() {
    return CapturedAutomationEvent(
      id: 'capture-1',
      source: CapturedEventSource(
        capability: AutomationSourceCapability.notification,
        sourceAppId: 'wechat',
        eventId: 'notification-1',
        eventIdHash: 'hmac-sha256:notification-1',
        observedAt: DateTime.utc(2026, 8, 23, 10),
      ),
      lifecycle: PlatformEventLifecycle.posted,
      capturedAt: DateTime.utc(2026, 8, 23, 10),
      textFragments: const <CapturedTextFragment>[
        CapturedTextFragment(
          role: CapturedTextRole.body,
          value: 'synthetic payment text',
        ),
      ],
    );
  }

  test('lease exposes immutable events and attempt metadata', () {
    final lease = PlatformEventLease(
      token: 'ephemeral-token',
      expiresAt: DateTime.utc(2026, 8, 23, 10, 1),
      events: <LeasedPlatformEvent>[
        LeasedPlatformEvent(
          event: event(),
          firstEnqueuedAt: DateTime.utc(2026, 8, 23, 10),
          rawExpiresAt: DateTime.utc(2026, 8, 24, 10),
          attemptCount: 1,
        ),
      ],
    );

    expect(lease.isEmpty, isFalse);
    expect(lease.events.single.attemptCount, 1);
    expect(() => lease.events.clear(), throwsUnsupportedError);
  });

  test('lease mutation result reports an expired token without mutation', () {
    const result = PlatformEventMutationResult(
      status: PlatformEventMutationStatus.leaseExpired,
    );

    expect(result.status, PlatformEventMutationStatus.leaseExpired);
    expect(CapturedAutomationEvent.currentPayloadSchemaVersion, 1);
  });

  test('renewal request requires a positive extension', () {
    expect(
      () => PlatformEventRenewalRequest(
        leaseToken: 'ephemeral-token',
        requestedExtension: Duration.zero,
      ),
      throwsArgumentError,
    );
  });

  test('lease rejects an invalid attempt count', () {
    expect(
      () => LeasedPlatformEvent(
        event: event(),
        firstEnqueuedAt: DateTime.utc(2026, 8, 23, 10),
        rawExpiresAt: DateTime.utc(2026, 8, 24, 10),
        attemptCount: 0,
      ),
      throwsArgumentError,
    );
  });

  test('lease rejects duplicate capture IDs', () {
    final captured = event();

    expect(
      () => PlatformEventLease(
        token: 'ephemeral-token',
        expiresAt: DateTime.utc(2026, 8, 23, 10, 1),
        events: <LeasedPlatformEvent>[
          LeasedPlatformEvent(
            event: captured,
            firstEnqueuedAt: DateTime.utc(2026, 8, 23, 10),
            rawExpiresAt: DateTime.utc(2026, 8, 24, 10),
            attemptCount: 1,
          ),
          LeasedPlatformEvent(
            event: captured,
            firstEnqueuedAt: DateTime.utc(2026, 8, 23, 10),
            rawExpiresAt: DateTime.utc(2026, 8, 24, 10),
            attemptCount: 1,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('raw recovery expiry cannot exceed 24 hours', () {
    expect(
      () => LeasedPlatformEvent(
        event: event(),
        firstEnqueuedAt: DateTime.utc(2026, 8, 23, 10),
        rawExpiresAt: DateTime.utc(2026, 8, 24, 10, 0, 1),
        attemptCount: 1,
      ),
      throwsArgumentError,
    );
  });
}
