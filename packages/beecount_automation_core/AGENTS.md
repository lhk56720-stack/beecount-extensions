# Automation core rules

- Pure Dart only. No Flutter, Android, UI, network, database, or BeeCount imports.
- Own candidate normalization, deduplication, posting decisions, mapping, rules, and retention policy.
- Payment semantics must exist here only, never duplicated in Kotlin or UI code.
- Use sanitized fixtures and table-driven tests for every rule.
