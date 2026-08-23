import 'package:beecount_extension_api/beecount_extension_api.dart';
import 'package:test/test.dart';

void main() {
  test('capability manifest round-trips independent switches', () {
    final descriptor = CapabilityDescriptor.fromJson(<String, Object?>{
      'id': 'automation.accessibility_text',
      'version': '1.0.0',
      'defaultEnabled': false,
      'permissions': <String>['android.accessibilityService'],
      'dependencies': <String>[],
      'dataRetention': 'memory-only minimized text',
      'networkBehavior': 'none unless AI capability is separately enabled',
    });

    expect(descriptor.defaultEnabled, isFalse);
    expect(descriptor.permissions, hasLength(1));
    expect(descriptor.dependencies, isEmpty);
    expect(descriptor.toJson()['id'], 'automation.accessibility_text');
  });

  test('revoked permission stops work without changing user preference', () {
    const status = CapabilityStatus(
      id: 'automation.notification',
      availability: CapabilityAvailability.available,
      enabled: true,
      permissionState: CapabilityPermissionState.serviceDisabled,
      health: CapabilityHealth.unavailable,
    );

    expect(status.enabled, isTrue);
    expect(status.isOperational, isFalse);
  });

  test('healthy enabled capability with granted permission is operational', () {
    const status = CapabilityStatus(
      id: 'automation.notification',
      availability: CapabilityAvailability.available,
      enabled: true,
      permissionState: CapabilityPermissionState.granted,
      health: CapabilityHealth.healthy,
    );

    expect(status.isOperational, isTrue);
  });
}
