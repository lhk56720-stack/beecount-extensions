# Android automation rules

- Own Android platform I/O only: notification/SMS collection, independently enabled accessibility text collection, permission state, native recovery queue, and verified system integrations.
- Emit minimized platform events; do not decide categories, accounts, deduplication, or posting.
- Every sensitive permission is a separate capability, defaults off, and needs an ADR plus denial/degradation tests.
- Accessibility must be limited by enabled package and payment-result-page guards, must not click/type/capture screenshots, and must degrade to notification collection when unavailable.
- Do not put raw notification or SMS text in logs.
