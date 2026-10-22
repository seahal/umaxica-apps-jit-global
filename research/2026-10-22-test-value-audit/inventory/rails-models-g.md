# rails-models-g: per-definition ledger

1 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/models/group_avatar_membership_test.rb`

[test/models/group_avatar_membership_test.rb](../../../test/models/group_avatar_membership_test.rb); SHA-256: `66a7b4a3c643d0bd4c6fa6ee7c94dcedf5bcb3dfe27e134348ebe076fd156cf7`.

File-level implementation candidates (including setup/import context): [app/models/group_avatar_membership.rb:4](../../../app/models/group_avatar_membership.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07442"></a>T-07442 / [6](../../../test/models/group_avatar_membership_test.rb#L6) | "public_id is a fixed 21-character NanoID"<br>Owner: `GroupAvatarMembershipTest` | `assert_public_id_fixed_length(::GroupAvatarMembership)` | [GroupAvatarMembership](../../../app/models/group_avatar_membership.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
