# API package rules

- Pure Dart only: no Flutter, Android, Riverpod, Drift, or BeeCount imports.
- Keep DTOs immutable and contracts implementation-agnostic.
- Breaking changes require an ADR, migration notes, and a major version change.
- Do not add business rules or platform I/O here.
