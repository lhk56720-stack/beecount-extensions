# Extension harness rules

- Use fake `ExtensionHostServices`; never depend on BeeCount internals.
- Keep sample data synthetic and sanitized.
- The harness may exercise UI and lifecycle behavior but must not request real sensitive permissions by default.
