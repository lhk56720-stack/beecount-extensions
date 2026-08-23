import '../model/captured_event.dart';

final class PlatformEventLease {
  PlatformEventLease({
    required this.token,
    required this.expiresAt,
    required List<LeasedPlatformEvent> events,
  }) : events = List<LeasedPlatformEvent>.unmodifiable(events) {
    if (token.isEmpty) {
      throw ArgumentError.value(token, 'token', 'must not be empty');
    }
    final captureIds = <String>{};
    for (final item in this.events) {
      if (!captureIds.add(item.event.id)) {
        throw ArgumentError.value(
          item.event.id,
          'events',
          'capture IDs must be unique within a lease',
        );
      }
      if (!expiresAt.isAfter(item.firstEnqueuedAt)) {
        throw ArgumentError.value(
          expiresAt,
          'expiresAt',
          'must be after every event first-enqueue time',
        );
      }
      if (expiresAt.isAfter(item.rawExpiresAt)) {
        throw ArgumentError.value(
          expiresAt,
          'expiresAt',
          'lease expiry must not exceed raw-event expiry',
        );
      }
    }
  }

  final String token;
  final DateTime expiresAt;
  final List<LeasedPlatformEvent> events;

  bool get isEmpty => events.isEmpty;
}

final class LeasedPlatformEvent {
  LeasedPlatformEvent({
    required this.event,
    required this.firstEnqueuedAt,
    required this.rawExpiresAt,
    required this.attemptCount,
  }) {
    if (attemptCount < 1) {
      throw ArgumentError.value(
        attemptCount,
        'attemptCount',
        'must be at least 1 after leasing',
      );
    }
    if (firstEnqueuedAt.isBefore(event.capturedAt)) {
      throw ArgumentError.value(
        firstEnqueuedAt,
        'firstEnqueuedAt',
        'must not be before capture time',
      );
    }
    final maximumRawExpiry = firstEnqueuedAt.add(const Duration(hours: 24));
    if (!rawExpiresAt.isAfter(firstEnqueuedAt) ||
        rawExpiresAt.isAfter(maximumRawExpiry)) {
      throw ArgumentError.value(
        rawExpiresAt,
        'rawExpiresAt',
        'must be after first enqueue and no later than 24 hours after it',
      );
    }
  }

  final CapturedAutomationEvent event;
  final DateTime firstEnqueuedAt;
  final DateTime rawExpiresAt;
  final int attemptCount;
}

enum PlatformEventFailureDisposition {
  retryable,
  permanent,
}

enum PlatformEventMutationStatus {
  applied,
  alreadyApplied,
  leaseExpired,
  leaseNotFound,
  eventNotInLease,
}

final class PlatformEventMutationResult {
  const PlatformEventMutationResult({
    required this.status,
  });

  final PlatformEventMutationStatus status;
}

final class PlatformEventRenewalRequest {
  PlatformEventRenewalRequest({
    required this.leaseToken,
    required this.requestedExtension,
  }) {
    if (leaseToken.isEmpty) {
      throw ArgumentError.value(leaseToken, 'leaseToken', 'must not be empty');
    }
    if (requestedExtension.inMicroseconds <= 0) {
      throw ArgumentError.value(
        requestedExtension,
        'requestedExtension',
        'must be positive',
      );
    }
  }

  final String leaseToken;
  final Duration requestedExtension;
}

final class PlatformEventRenewalResult {
  PlatformEventRenewalResult({
    required this.status,
    this.lease,
  }) {
    if ((status == PlatformEventMutationStatus.applied) != (lease != null)) {
      throw ArgumentError(
        'an applied renewal must return a lease and failures must not',
      );
    }
  }

  final PlatformEventMutationStatus status;
  final PlatformEventLease? lease;
}

/// At-least-once crash-recovery queue for sensitive platform events.
///
/// Contract:
///
/// - Enqueueing the same capture [CapturedAutomationEvent.id] is idempotent.
/// - A lease increments the attempt count and temporarily hides its events.
/// - An expired or explicitly released lease makes unacknowledged events
///   available again.
/// - A retryable failure applies backoff; a permanent failure destroys the
///   payload and retains only a local tombstone with a safe reason code.
/// - The absolute raw-event expiry remains 24 hours from first enqueue,
///   regardless of retry or dead-letter state.
///
/// Effective-once bookkeeping is achieved above this queue through stable
/// source identities, candidate updates, deduplication, and idempotent posting
/// keys, with one serialized posting coordinator per ledger. A queue
/// implementation must never claim exactly-once delivery.
abstract interface class PlatformEventQueuePort {
  Future<void> enqueue(CapturedAutomationEvent event);

  Future<PlatformEventLease> lease({
    required int limit,
    required Duration leaseDuration,
  });

  /// Extends only an active lease. An expired or unknown token never changes
  /// ownership and returns an explicit non-applied status. The returned lease
  /// expiry must be capped by the record's absolute raw-data expiry, which is
  /// at most 24 hours after first enqueue; renewal can never extend that TTL.
  /// The implementation caps the new lease to the earliest raw expiry among
  /// all remaining events. The returned [PlatformEventLease] enforces that
  /// bound for every event in the batch.
  Future<PlatformEventRenewalResult> renew(
    PlatformEventRenewalRequest request,
  );

  /// Acknowledges one event so partial batch completion is unambiguous.
  /// Repeating a successful acknowledgement is idempotent.
  Future<PlatformEventMutationResult> acknowledge({
    required String leaseToken,
    required String captureId,
  });

  /// Releases all still-unacknowledged events in the active lease.
  Future<PlatformEventMutationResult> release(String leaseToken);

  /// A retryable failure requires [retryAfter]. A permanent failure requires
  /// it to be null, destroys the encrypted payload, and retains only a safe
  /// tombstone until absolute expiry.
  Future<PlatformEventMutationResult> fail({
    required String leaseToken,
    required String captureId,
    required PlatformEventFailureDisposition disposition,
    required String safeReasonCode,
    DateTime? retryAfter,
  });

  Future<int> purgeExpired(DateTime now);
}
