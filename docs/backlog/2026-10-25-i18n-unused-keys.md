# Review unused translation keys before deletion

Status: Deferred. The existing CI `unused` check reports **4,682 locale entries** on 2026-10-25.

The count includes entries in both `en.yml` and `ja.yml`. It is not a safe deletion list: the
application selects translation keys through finite maps, variable scopes, and runtime-built
prefixes that `i18n-tasks` does not reliably resolve. The 2026-10-25 parity repair restored 18
keys in each language after tracing those call sites and the Active Record attribute used by
validation; deleting every reported entry would remove live authentication and preference copy.

Before deleting any entry, inventory the emitted keys at each dynamic call site, compare them with
the unused output, and retain or explicitly retire keys with live callers. Re-run `i18n-tasks
unused`, verify locale key parity, and exercise the affected public flows after each bounded cleanup.
