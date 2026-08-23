# Development

## Current gate

The repository is in Stage 1 contract/core development. Pure-Dart package manifests, API/core source, sanitized fixtures, tests, schemas, ADRs, and separately scoped Android feasibility spikes are allowed. Android production services, permissions, bundle implementation, and BeeCount integration remain blocked.

Do not run Flutter, Dart, Gradle, code generation, dependency resolution, compilation, or Android build commands on the development server. The user approved fixed Remote Builder profiles on 2026-08-24 under these conditions:

- source must already be committed and pushed to the registered public GitHub repository;
- the controller resolves the source ref to an immutable 40-character commit SHA;
- only reviewed profiles may run, with no caller-supplied shell commands;
- credentials, raw notification data, private fixtures, APKs, and build archives must never be committed;
- contract verification does not approve Android permissions, services, or BeeCount host integration.

Stage 1 remote verification is limited to formatting checks, static analysis, package tests, and schema validation for `beecount_extension_api` and `beecount_automation_core`. Android APK builds become meaningful only after a reviewed host integration consumes the extension bundle.

## Future implementation workflow

1. Read root and package `AGENTS.md` files.
2. Select exactly one primary package for the task.
3. Add tests for normal, duplicate, failure/retry, and disabled-capability behavior where applicable.
4. Run the architecture checks, analysis, and affected tests created during the approved implementation phase.
5. Update ADR, privacy, compatibility, and third-party notices when their boundaries change.

Do not combine an upstream BeeCount sync with extension feature work.
