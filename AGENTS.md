# BeeCount Extensions agent rules

Read `docs/architecture.md`, the relevant ADR, and the target package's `AGENTS.md` before editing.

## Boundaries

- Keep `beecount_extension_api` and `beecount_automation_core` pure Dart.
- Put Android I/O only in `beecount_automation_android`.
- Put capability composition, settings, and extension UI only in `beecount_extensions_bundle`.
- Never import `package:beecount/` from this repository.
- Never let AI or platform collectors write formal transactions directly.
- New permissions, data egress, packages, or destructive accounting behavior require an ADR and human approval.
- Do not copy GPL or unlicensed source code. Record every third-party dependency in `THIRD_PARTY_NOTICES.md`.

## Completion

Run architecture checks, analysis, and the tests for every changed package. Report permissions, storage, network behavior, compatibility, and unverified items.
