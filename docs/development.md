# Development

## Current gate

The repository is in Stage 2 notification MVP development. ADR-0004 approves the Android notification listener, bounded source registry, encrypted recovery queue, permission state, local deterministic parsing, Bundle composition, and a thin BeeCount host integration. AI data egress, accessibility, SMS, HyperOS presentation, active screenshots, Shizuku, and Root remain blocked.

Do not run Flutter, Gradle, code generation, dependency resolution, static analysis, tests, compilation, or Android build commands on the development server. Low-resource `dart format` is allowed because it does not resolve dependencies or compile source. The user approved fixed Remote Builder profiles on 2026-08-24 under these conditions:

- source must already be committed and pushed to the registered public GitHub repository;
- the controller resolves the source ref to an immutable 40-character commit SHA;
- only reviewed profiles may run, with no caller-supplied shell commands;
- credentials, raw notification data, private fixtures, APKs, and build archives must never be committed;
- contract verification does not approve Android permissions, services, or BeeCount host integration.

Remote verification must expand with each implemented package. Android APK builds become release candidates only after a reviewed host integration consumes a pinned extension commit and the extension-disabled regression passes.

## Future implementation workflow

1. Read root and package `AGENTS.md` files.
2. Select exactly one primary package for the task.
3. Add tests for normal, duplicate, failure/retry, and disabled-capability behavior where applicable.
4. Run the architecture checks, analysis, and affected tests created during the approved implementation phase.
5. Update ADR, privacy, compatibility, and third-party notices when their boundaries change.

Do not combine an upstream BeeCount sync with extension feature work.
