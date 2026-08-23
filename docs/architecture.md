# Architecture

The normative architecture decision is maintained in the adjacent research repository:

`../auto-bookkeeping-research/docs/beecount-extension-architecture-governance.md`

Dependency direction:

```text
automation_core ------> extension_api
automation_android ---> extension_api
extensions_bundle ----> extension_api + automation_core + automation_android
BeeCount host --------> extension_api + extensions_bundle
```

No package in this repository may import BeeCount internals. Formal accounting data remains owned by BeeCount and is accessed only through host ports. Capabilities are compiled into the app and can be enabled independently at runtime; remote executable plugins are out of scope.
