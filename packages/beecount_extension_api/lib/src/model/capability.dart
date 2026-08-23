enum CapabilityAvailability {
  available,
  unsupported,
  approvalRequired,
}

enum CapabilityPermissionState {
  notRequired,
  notRequested,
  granted,
  denied,
  restricted,
  serviceDisabled,
}

enum CapabilityHealth {
  unknown,
  healthy,
  degraded,
  unavailable,
  error,
}

final class CapabilityDescriptor {
  CapabilityDescriptor({
    required this.id,
    required this.version,
    required this.defaultEnabled,
    required List<String> permissions,
    required List<String> dependencies,
    required this.dataRetention,
    required this.networkBehavior,
  })  : permissions = List<String>.unmodifiable(permissions),
        dependencies = List<String>.unmodifiable(dependencies);

  final String id;
  final String version;
  final bool defaultEnabled;
  final List<String> permissions;
  final List<String> dependencies;
  final String dataRetention;
  final String networkBehavior;

  factory CapabilityDescriptor.fromJson(Map<String, Object?> json) {
    return CapabilityDescriptor(
      id: _requiredString(json, 'id'),
      version: _requiredString(json, 'version'),
      defaultEnabled: _requiredBool(json, 'defaultEnabled'),
      permissions: _stringList(json, 'permissions'),
      dependencies: _stringList(json, 'dependencies'),
      dataRetention: _requiredString(json, 'dataRetention'),
      networkBehavior: _requiredString(json, 'networkBehavior'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'version': version,
        'defaultEnabled': defaultEnabled,
        'permissions': permissions,
        'dependencies': dependencies,
        'dataRetention': dataRetention,
        'networkBehavior': networkBehavior,
      };
}

final class CapabilityStatus {
  const CapabilityStatus({
    required this.id,
    required this.availability,
    required this.enabled,
    required this.permissionState,
    required this.health,
    this.safeErrorCode,
    this.lastCheckedAt,
  });

  final String id;
  final CapabilityAvailability availability;
  final bool enabled;
  final CapabilityPermissionState permissionState;
  final CapabilityHealth health;
  final String? safeErrorCode;
  final DateTime? lastCheckedAt;

  /// Whether the capability can currently do useful work.
  ///
  /// [enabled] is the user's retained preference. Permission revocation may
  /// make an enabled capability non-operational without silently changing that
  /// preference or activating a different capability.
  bool get isOperational {
    final permissionReady =
        permissionState == CapabilityPermissionState.notRequired ||
            permissionState == CapabilityPermissionState.granted;
    final healthReady = health == CapabilityHealth.healthy ||
        health == CapabilityHealth.degraded;
    return enabled &&
        availability == CapabilityAvailability.available &&
        permissionReady &&
        healthReady;
  }
}

abstract interface class CapabilityController {
  CapabilityDescriptor get descriptor;

  Future<CapabilityStatus> getStatus();

  Future<CapabilityStatus> enable();

  Future<CapabilityStatus> disable();
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean');
  return value;
}

List<String> _stringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null && key == 'dependencies') return const <String>[];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$key must be an array of strings');
  }
  return value.cast<String>();
}
