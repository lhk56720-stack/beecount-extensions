# Privacy baseline

- Parse locally by default and collect only fields required to create a candidate transaction.
- Never log raw notifications, SMS bodies, account numbers, or AI input text.
- Raw platform events are memory-only by default. A crash-recovery queue, when implemented, must expire within 24 hours.
- Candidate and deduplication data are local and excluded from BeeCount cloud sync and export by default.
- Automatic-bookkeeping diagnostics retain at most 200 encrypted local structural events. They may contain a timestamp, reviewed source ID, state transition, and safe machine error code, but never notification text, amount, merchant, account data, platform event ID, HMAC identity, or transaction content. Users can clear them independently.
- Platform event IDs are HMAC-tokenized before entering candidates; evidence stores only that identity and offsets, never normalized text copies.
- AI data egress, SMS, and accessibility each require an independent capability switch and an approved ADR. Accessibility is a first-phase optional enhancement, never a notification dependency, and may process only minimized text from enabled apps' payment-result pages.
- Active screenshot capture, Shizuku, Root, Xposed, and private hooks are outside the first implementation scope. Existing user-triggered screenshot bookkeeping remains owned by BeeCount and only joins shared deduplication before posting.

## Capability switch and permission behavior

The UI has one automation master switch plus independent capability switches. A source switch controls permission and collection; the master switch controls whether any automatic collection or posting runs. Turning the master switch off preserves configured source preferences and structured candidates but stops collectors and clears unconsumed raw recovery records.

On first enable, explain and request only the permission for that capability. If the user declines or cancels, the switch returns to off and no prompt loop is allowed. If a previously granted permission is revoked while enabled, collection stops immediately, the capability reports unavailable, and the UI offers one explicit repair action. It must never activate a more sensitive fallback automatically.

| Capability | Effective behavior when unavailable or disabled |
|---|---|
| Notification source | No notification text is copied; existing candidates remain |
| Local parser | Candidate remains incomplete or pending |
| AI text enhancement | No network request; local result remains pending |
| Accessibility text | No node text is read; notification processing continues independently |
| SMS source | No SMS body is read; other enabled sources continue independently |
| HyperOS presentation | Fall back only to a privacy-safe ordinary notification when separately allowed |
| Existing screenshot bookkeeping | Remains user-triggered BeeCount behavior; no active capture permission is added |

AI enhancement uses local parsing first. It may be called only when required structured fields remain unresolved and its independent switch is enabled. Send only minimized transaction fragments needed for those fields; never send a complete notification, SMS, accessibility tree, account number, package dump, or event history.

The normative recovery and degradation decision is `docs/adr/0003-event-recovery-and-capability-degradation.md`.
