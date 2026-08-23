import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:flutter/services.dart';

import 'notification_source_registry.dart';

final class NotificationCaptureConfiguration {
  NotificationCaptureConfiguration({
    required this.automationEnabled,
    required this.notificationEnabled,
    required Set<String> enabledPackageNames,
  }) : enabledPackageNames = Set<String>.unmodifiable(enabledPackageNames) {
    final supportedPackages = NotificationSourceRegistry.supported
        .map((source) => source.packageName)
        .toSet();
    final unsupported = this.enabledPackageNames.difference(supportedPackages);
    if (unsupported.isNotEmpty) {
      throw ArgumentError.value(
        unsupported,
        'enabledPackageNames',
        'contains packages outside the reviewed source registry',
      );
    }
  }

  final bool automationEnabled;
  final bool notificationEnabled;
  final Set<String> enabledPackageNames;

  Map<String, Object?> toPlatformMap() => <String, Object?>{
        'automationEnabled': automationEnabled,
        'notificationEnabled': notificationEnabled,
        'enabledPackageNames': enabledPackageNames.toList(growable: false),
      };
}

final class NotificationCollectionStatus {
  const NotificationCollectionStatus({
    required this.platformSupported,
    required this.accessGranted,
    required this.serviceConnected,
    required this.automationEnabled,
    required this.notificationEnabled,
    required this.pendingEventCount,
    required this.enabledPackageNames,
  });

  final bool platformSupported;
  final bool accessGranted;
  final bool serviceConnected;
  final bool automationEnabled;
  final bool notificationEnabled;
  final int pendingEventCount;
  final Set<String> enabledPackageNames;

  bool get isOperational =>
      platformSupported &&
      accessGranted &&
      automationEnabled &&
      notificationEnabled &&
      enabledPackageNames.isNotEmpty;

  factory NotificationCollectionStatus.fromPlatformMap(
    Map<Object?, Object?> map,
  ) {
    final rawPackages = map['enabledPackageNames'];
    if (rawPackages is! List) {
      throw const FormatException('enabledPackageNames must be a list');
    }
    return NotificationCollectionStatus(
      platformSupported: _requiredBool(map, 'platformSupported'),
      accessGranted: _requiredBool(map, 'accessGranted'),
      serviceConnected: _requiredBool(map, 'serviceConnected'),
      automationEnabled: _requiredBool(map, 'automationEnabled'),
      notificationEnabled: _requiredBool(map, 'notificationEnabled'),
      pendingEventCount: _requiredInt(map, 'pendingEventCount'),
      enabledPackageNames: Set<String>.unmodifiable(
        rawPackages.map((item) => item as String),
      ),
    );
  }
}

final class NotificationAutomationPlatform implements PlatformEventQueuePort {
  NotificationAutomationPlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName =
      'dev.beecount.extensions/notification_automation';

  final MethodChannel _channel;

  Future<NotificationCollectionStatus> getStatus() async {
    final result = await _invokeMap('getStatus');
    return NotificationCollectionStatus.fromPlatformMap(result);
  }

  Future<NotificationCollectionStatus> configure(
    NotificationCaptureConfiguration configuration,
  ) async {
    final result = await _invokeMap(
      'configure',
      configuration.toPlatformMap(),
    );
    return NotificationCollectionStatus.fromPlatformMap(result);
  }

  Future<bool> openNotificationAccessSettings() async {
    return await _channel.invokeMethod<bool>('openNotificationAccessSettings') ??
        false;
  }

  @override
  Future<void> enqueue(CapturedAutomationEvent event) {
    throw UnsupportedError(
      'platform events are enqueued only by the native notification listener',
    );
  }

  @override
  Future<PlatformEventLease> lease({
    required int limit,
    required Duration leaseDuration,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 100');
    }
    if (leaseDuration <= Duration.zero) {
      throw ArgumentError.value(
        leaseDuration,
        'leaseDuration',
        'must be positive',
      );
    }
    final result = await _invokeMap('leaseEvents', <String, Object?>{
      'limit': limit,
      'leaseDurationMs': leaseDuration.inMilliseconds,
    });
    return _decodeLease(result);
  }

  @override
  Future<PlatformEventRenewalResult> renew(
    PlatformEventRenewalRequest request,
  ) async {
    final result = await _invokeMap('renewLease', <String, Object?>{
      'leaseToken': request.leaseToken,
      'requestedExtensionMs': request.requestedExtension.inMilliseconds,
    });
    final status = _mutationStatus(result['status']);
    final rawLease = result['lease'];
    return PlatformEventRenewalResult(
      status: status,
      lease: rawLease == null
          ? null
          : _decodeLease(_asMap(rawLease, 'lease')),
    );
  }

  @override
  Future<PlatformEventMutationResult> acknowledge({
    required String leaseToken,
    required String captureId,
  }) async {
    return _mutationResult(await _invokeMap('acknowledgeEvent', <String, Object?>{
      'leaseToken': leaseToken,
      'captureId': captureId,
    }));
  }

  @override
  Future<PlatformEventMutationResult> release(String leaseToken) async {
    return _mutationResult(await _invokeMap('releaseLease', <String, Object?>{
      'leaseToken': leaseToken,
    }));
  }

  @override
  Future<PlatformEventMutationResult> fail({
    required String leaseToken,
    required String captureId,
    required PlatformEventFailureDisposition disposition,
    required String safeReasonCode,
    DateTime? retryAfter,
  }) async {
    if (disposition == PlatformEventFailureDisposition.retryable &&
        retryAfter == null) {
      throw ArgumentError('retryAfter is required for retryable failures');
    }
    if (disposition == PlatformEventFailureDisposition.permanent &&
        retryAfter != null) {
      throw ArgumentError('retryAfter must be null for permanent failures');
    }
    return _mutationResult(await _invokeMap('failEvent', <String, Object?>{
      'leaseToken': leaseToken,
      'captureId': captureId,
      'disposition': disposition.name,
      'safeReasonCode': safeReasonCode,
      'retryAfterMs': retryAfter?.millisecondsSinceEpoch,
    }));
  }

  @override
  Future<int> purgeExpired(DateTime now) async {
    return await _channel.invokeMethod<int>('purgeExpired', <String, Object?>{
          'nowMs': now.millisecondsSinceEpoch,
        }) ??
        0;
  }

  Future<Map<Object?, Object?>> _invokeMap(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    final result = await _channel.invokeMethod<Object?>(method, arguments);
    return _asMap(result, method);
  }
}

PlatformEventLease _decodeLease(Map<Object?, Object?> map) {
  final rawEvents = map['events'];
  if (rawEvents is! List) {
    throw const FormatException('lease events must be a list');
  }
  return PlatformEventLease(
    token: _requiredString(map, 'token'),
    expiresAt: _dateTimeFromMs(map, 'expiresAtMs'),
    events: rawEvents.map((item) {
      final leased = _asMap(item, 'leasedEvent');
      return LeasedPlatformEvent(
        event: _decodeEvent(_asMap(leased['event'], 'event')),
        firstEnqueuedAt: _dateTimeFromMs(leased, 'firstEnqueuedAtMs'),
        rawExpiresAt: _dateTimeFromMs(leased, 'rawExpiresAtMs'),
        attemptCount: _requiredInt(leased, 'attemptCount'),
      );
    }).toList(growable: false),
  );
}

CapturedAutomationEvent _decodeEvent(Map<Object?, Object?> map) {
  final rawSource = _asMap(map['source'], 'source');
  final rawFragments = map['textFragments'];
  if (rawFragments is! List) {
    throw const FormatException('textFragments must be a list');
  }
  return CapturedAutomationEvent(
    id: _requiredString(map, 'id'),
    source: CapturedEventSource(
      capability: AutomationSourceCapability.notification,
      sourceAppId: _requiredString(rawSource, 'sourceAppId'),
      packageName: _optionalString(rawSource, 'packageName'),
      eventId: _requiredString(rawSource, 'eventId'),
      eventIdHash: _requiredString(rawSource, 'eventIdHash'),
      supersedesEventId: _optionalString(rawSource, 'supersedesEventId'),
      supersedesEventIdHash:
          _optionalString(rawSource, 'supersedesEventIdHash'),
      observedAt: _dateTimeFromMs(rawSource, 'observedAtMs'),
    ),
    lifecycle: PlatformEventLifecycle.values.byName(
      _requiredString(map, 'lifecycle'),
    ),
    capturedAt: _dateTimeFromMs(map, 'capturedAtMs'),
    textFragments: rawFragments.map((item) {
      final fragment = _asMap(item, 'textFragment');
      return CapturedTextFragment(
        role: CapturedTextRole.values.byName(
          _requiredString(fragment, 'role'),
        ),
        value: _requiredString(fragment, 'value'),
      );
    }).toList(growable: false),
  );
}

PlatformEventMutationResult _mutationResult(Map<Object?, Object?> map) {
  return PlatformEventMutationResult(status: _mutationStatus(map['status']));
}

PlatformEventMutationStatus _mutationStatus(Object? value) {
  if (value is! String) {
    throw const FormatException('mutation status must be a string');
  }
  return PlatformEventMutationStatus.values.byName(value);
}

Map<Object?, Object?> _asMap(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be a map');
  return value;
}

String _requiredString(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? _optionalString(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be null or a non-empty string');
  }
  return value;
}

bool _requiredBool(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value is! bool) throw FormatException('$key must be a boolean');
  return value;
}

int _requiredInt(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value is! int) throw FormatException('$key must be an integer');
  return value;
}

DateTime _dateTimeFromMs(Map<Object?, Object?> map, String key) {
  return DateTime.fromMillisecondsSinceEpoch(_requiredInt(map, key), isUtc: true);
}
