# BeeCount Extensions

Public extension workspace for BeeCount capability contracts, pure-Dart automation rules, Android platform collection, and a single host-facing bundle.

## Current phase

**Stage 1 contract/core development is approved.** Work is limited to the pure-Dart API contract, pure-Dart automation core, sanitized fixtures, tests, ADRs, and narrowly scoped standalone Android feasibility spikes. Android production services, permissions, and BeeCount integration remain unapproved.

The development server must not run Flutter, Gradle, code generation, dependency resolution, static analysis, tests, compilation, or Android builds. Low-resource `dart format` is allowed because it neither resolves dependencies nor compiles code. The approved Remote Builder runs complete fixed verification profiles against an immutable commit SHA on GitHub-hosted runners. Remote verification does not approve Android production implementation or host integration by itself.

Exit criteria are maintained in `../auto-bookkeeping-research/docs/phase-0-auto-bookkeeping-readiness-checklist.md`.

## Packages

- `beecount_extension_api`: stable pure-Dart host and capability contracts.
- `beecount_automation_core`: pure-Dart automation domain logic.
- `beecount_automation_android`: Android platform plugin boundary.
- `beecount_extensions_bundle`: the only package the BeeCount host should depend on.

Read `docs/architecture.md` and `AGENTS.md` before making changes. The detailed trees in the architecture RFC describe the future implementation target, not code that must exist in the current phase.
