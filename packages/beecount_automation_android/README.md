# beecount_automation_android

Android platform adapter for notification-first automatic bookkeeping.

The package owns the `NotificationListenerService`, permission-state bridge,
reviewed source allowlist, and encrypted short-lived native recovery queue. It
does not parse transactions, call AI, write BeeCount records, or request
accessibility, screenshot, SMS, Shizuku, or Root access.

The capability is default-off and requires both the in-app switch and explicit
notification-access authorization in Android settings. See ADR 0004 before
changing its permission, retention, or data boundary.
