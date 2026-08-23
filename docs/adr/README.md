# Architecture decision records

Use one file per decision: `NNNN-short-title.md`. Include status, context, decision, consequences, privacy/permission impact, and rollback strategy.

An ADR is mandatory for a new package, breaking API change, sensitive permission, data egress, remote code, unsafe degradation, or mutation/deletion of formal transactions.

Current decisions:

- `0001-stage-1-contract-core.md`: Stage 1 pure-Dart contract and core scope.
- `0002-transaction-semantics-and-posting-gates.md`: transaction kinds and automatic-posting gates.
- `0003-event-recovery-and-capability-degradation.md`: at-least-once recovery and independent capability degradation.
- `0004-notification-collection-capability.md`: default-off Android notification collection and encrypted recovery boundary.
