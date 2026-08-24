# beecount_extensions_bundle

Composition package for BeeCount extensions. It is the host's only extension
dependency and owns foreground notification-queue draining, local candidate
state, Core posting gates, source/account settings, and the pending-candidate
UI.

Notification collection remains default-off. The first version has no AI,
accessibility, SMS, screenshot automation, HyperOS island, Shizuku, or Root
capability. Each capability directory keeps its machine-readable declaration.
