import 'package:beecount_automation_android/beecount_automation_android.dart';
import 'package:beecount_extension_api/beecount_extension_api.dart';

abstract interface class AutomationPlatformBridge
    implements PlatformEventQueuePort {
  Future<NotificationCollectionStatus> getStatus();

  Future<NotificationCollectionStatus> configure(
    NotificationCaptureConfiguration configuration,
  );

  Future<bool> openNotificationAccessSettings();

  Future<Map<String, Object?>?> readLocalState();

  Future<void> writeLocalState(Map<String, Object?> state);
}

final class AndroidAutomationPlatformBridge implements AutomationPlatformBridge {
  AndroidAutomationPlatformBridge({NotificationAutomationPlatform? platform})
      : _platform = platform ?? NotificationAutomationPlatform();

  final NotificationAutomationPlatform _platform;

  @override
  Future<NotificationCollectionStatus> getStatus() => _platform.getStatus();

  @override
  Future<NotificationCollectionStatus> configure(
    NotificationCaptureConfiguration configuration,
  ) =>
      _platform.configure(configuration);

  @override
  Future<bool> openNotificationAccessSettings() =>
      _platform.openNotificationAccessSettings();

  @override
  Future<Map<String, Object?>?> readLocalState() => _platform.readLocalState();

  @override
  Future<void> writeLocalState(Map<String, Object?> state) =>
      _platform.writeLocalState(state);

  @override
  Future<void> enqueue(CapturedAutomationEvent event) => _platform.enqueue(event);

  @override
  Future<PlatformEventLease> lease({
    required int limit,
    required Duration leaseDuration,
  }) =>
      _platform.lease(limit: limit, leaseDuration: leaseDuration);

  @override
  Future<PlatformEventRenewalResult> renew(
    PlatformEventRenewalRequest request,
  ) =>
      _platform.renew(request);

  @override
  Future<PlatformEventMutationResult> acknowledge({
    required String leaseToken,
    required String captureId,
  }) =>
      _platform.acknowledge(leaseToken: leaseToken, captureId: captureId);

  @override
  Future<PlatformEventMutationResult> release(String leaseToken) =>
      _platform.release(leaseToken);

  @override
  Future<PlatformEventMutationResult> fail({
    required String leaseToken,
    required String captureId,
    required PlatformEventFailureDisposition disposition,
    required String safeReasonCode,
    DateTime? retryAfter,
  }) =>
      _platform.fail(
        leaseToken: leaseToken,
        captureId: captureId,
        disposition: disposition,
        safeReasonCode: safeReasonCode,
        retryAfter: retryAfter,
      );

  @override
  Future<int> purgeExpired(DateTime now) => _platform.purgeExpired(now);
}
