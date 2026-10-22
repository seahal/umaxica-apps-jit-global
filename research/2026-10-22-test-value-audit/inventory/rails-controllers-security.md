# rails-controllers-security: per-definition ledger

1 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/controllers/security/csrf_route_coverage_test.rb`

[test/controllers/security/csrf_route_coverage_test.rb](../../../test/controllers/security/csrf_route_coverage_test.rb); SHA-256: `470dea4fa631192337e9be34236a5ceee63444212d39085b70167be1857f0308`.

File-level implementation candidates (including setup/import context): [app/controllers/base/app/accounts_controller.rb:4](../../../app/controllers/base/app/accounts_controller.rb#L4); [app/controllers/base/app/api/v0/avatar/avatar_ownership_transfers_controller.rb:4](../../../app/controllers/base/app/api/v0/avatar/avatar_ownership_transfers_controller.rb#L4); [app/controllers/base/app/api/v0/avatar/avatars_controller.rb:4](../../../app/controllers/base/app/api/v0/avatar/avatars_controller.rb#L4); [app/controllers/base/app/api/v0/avatar/dashboard_identities_controller.rb:4](../../../app/controllers/base/app/api/v0/avatar/dashboard_identities_controller.rb#L4); [app/controllers/base/app/api/v0/avatar/group_avatar_memberships_controller.rb:4](../../../app/controllers/base/app/api/v0/avatar/group_avatar_memberships_controller.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-03274"></a>T-03274 / [28](../../../test/controllers/security/csrf_route_coverage_test.rb#L28) | "state-changing application routes do not use null-session csrf handling"<br>Owner: `Security::CsrfRouteCoverageTest` | `assert_empty violations,` | [Base](../../../app/controllers/base/app/accounts_controller.rb#L4); [Base](../../../app/controllers/base/app/api/v0/avatar/avatar_ownership_transfers_controller.rb#L4) | S: static inventory; individual semantic review open | conditional-reachability, coverage-named |
