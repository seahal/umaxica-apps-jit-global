# rails-models-h: per-definition ledger

16 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/models/handle_assignment_status_test.rb`

[test/models/handle_assignment_status_test.rb](../../../test/models/handle_assignment_status_test.rb); SHA-256: `acafb80f733a74c2f77be49990537747e41cffa3b1f2bcc891bf00525c787649`.

File-level implementation candidates (including setup/import context): [app/models/handle_assignment_status.rb:11](../../../app/models/handle_assignment_status.rb#L11).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07443"></a>T-07443 / [15](../../../test/models/handle_assignment_status_test.rb#L15) | "accepts integer ids"<br>Owner: `HandleAssignmentStatusTest` | `assert_predicate status, :valid?` | [HandleAssignmentStatus](../../../app/models/handle_assignment_status.rb#L11) | [LV-027](../findings.md#lv-027) candidate | none detected (not a quality approval) |
| <a id="t-07444"></a>T-07444 / [21](../../../test/models/handle_assignment_status_test.rb#L21) | "constants are defined"<br>Owner: `HandleAssignmentStatusTest` | `assert_equal 1, HandleAssignmentStatus::INACTIVE`; `assert_equal 2, HandleAssignmentStatus::PENDING`; `assert_equal 3, HandleAssignmentStatus::ACTIVE`; +2 further assertion lines | [HandleAssignmentStatus](../../../app/models/handle_assignment_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/handle_assignment_test.rb`

[test/models/handle_assignment_test.rb](../../../test/models/handle_assignment_test.rb); SHA-256: `cfa8bffaf15d192ca4df92a783d8e4ac517f1295d8d394ce34bf17c4394ca727`.

File-level implementation candidates (including setup/import context): [app/models/avatar_capability.rb:12](../../../app/models/avatar_capability.rb#L12); [app/models/handle.rb:31](../../../app/models/handle.rb#L31); [app/models/avatar.rb:43](../../../app/models/avatar.rb#L43); [app/models/handle_assignment.rb:37](../../../app/models/handle_assignment.rb#L37).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07445"></a>T-07445 / [54](../../../test/models/handle_assignment_test.rb#L54) | "current_attributes returns handle and avatar ids"<br>Owner: `HandleAssignmentTest` | `assert_equal [:handle_id, :avatar_id], HandleAssignment.current_attributes` | [HandleAssignment](../../../app/models/handle_assignment.rb#L37) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07446"></a>T-07446 / [58](../../../test/models/handle_assignment_test.rb#L58) | "valid_to defaults to infinity"<br>Owner: `HandleAssignmentTest` | `assert_predicate valid_to, :present?`; `assert valid_to.to_s == "infinity" \|\| (valid_to.is_a?(Float) && valid_to == Float::INFINITY)` | [HandleAssignment](../../../app/models/handle_assignment.rb#L37) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07447"></a>T-07447 / [71](../../../test/models/handle_assignment_test.rb#L71) | "prevents multiple active assignments for the same handle"<br>Owner: `HandleAssignmentTest` | `assert_raises ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique do` | [HandleAssignment](../../../app/models/handle_assignment.rb#L37); [Handle](../../../app/models/handle.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/handle_status_test.rb`

[test/models/handle_status_test.rb](../../../test/models/handle_status_test.rb); SHA-256: `dbb3ddf95903afa7c0c1ce207e2eb1d71923d6fef385da509f6b787369f5f4fb`.

File-level implementation candidates (including setup/import context): [app/models/handle_status.rb:11](../../../app/models/handle_status.rb#L11).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07448"></a>T-07448 / [17](../../../test/models/handle_status_test.rb#L17) | "validations"<br>Owner: `HandleStatusTest` | `assert_predicate status, :valid?` | [HandleStatus](../../../app/models/handle_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07449"></a>T-07449 / [23](../../../test/models/handle_status_test.rb#L23) | "can load active status from db"<br>Owner: `HandleStatusTest` | `assert_not_nil status`; `assert_equal HandleStatus::ACTIVE, status.id` | [HandleStatus](../../../app/models/handle_status.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/handle_test.rb`

[test/models/handle_test.rb](../../../test/models/handle_test.rb); SHA-256: `ae23c32a66176994152d7c581f64d3151fd1befa7f00124af150174a0e41f97a`.

File-level implementation candidates (including setup/import context): [app/models/handle.rb:31](../../../app/models/handle.rb#L31); [app/models/avatar_capability.rb:12](../../../app/models/avatar_capability.rb#L12); [app/models/avatar.rb:43](../../../app/models/avatar.rb#L43).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-07450"></a>T-07450 / [42](../../../test/models/handle_test.rb#L42) | "valid handle"<br>Owner: `HandleTest` | `assert_predicate @handle, :valid?`; `assert @handle.save` | [Handle](../../../app/models/handle.rb#L31); [AvatarCapability](../../../app/models/avatar_capability.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07451"></a>T-07451 / [47](../../../test/models/handle_test.rb#L47) | "requires handle"<br>Owner: `HandleTest` | `assert_not @handle.valid?`; `assert_not_empty @handle.errors[:handle]` | [Handle](../../../app/models/handle.rb#L31); [AvatarCapability](../../../app/models/avatar_capability.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07452"></a>T-07452 / [54](../../../test/models/handle_test.rb#L54) | "requires cooldown_until"<br>Owner: `HandleTest` | `assert_not @handle.valid?`; `assert_not_empty @handle.errors[:cooldown_until]` | [Handle](../../../app/models/handle.rb#L31); [AvatarCapability](../../../app/models/avatar_capability.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07453"></a>T-07453 / [61](../../../test/models/handle_test.rb#L61) | "handle uniqueness for non-system"<br>Owner: `HandleTest` | `assert_not duplicate.valid?`; `assert_not_empty duplicate.errors[:handle]` | [Handle](../../../app/models/handle.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07454"></a>T-07454 / [69](../../../test/models/handle_test.rb#L69) | "handle is invalid when empty"<br>Owner: `HandleTest` | `assert_not @handle.valid?`; `assert_not_empty @handle.errors[:handle]` | [Handle](../../../app/models/handle.rb#L31); [AvatarCapability](../../../app/models/avatar_capability.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07455"></a>T-07455 / [76](../../../test/models/handle_test.rb#L76) | "handle is invalid when only whitespace"<br>Owner: `HandleTest` | `assert_not @handle.valid?`; `assert_not_empty @handle.errors[:handle]` | [Handle](../../../app/models/handle.rb#L31); [AvatarCapability](../../../app/models/avatar_capability.rb#L12) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07456"></a>T-07456 / [83](../../../test/models/handle_test.rb#L83) | "public_id uniqueness"<br>Owner: `HandleTest` | `assert_not duplicate.valid?`; `assert_not_empty duplicate.errors[:public_id]` | [Handle](../../../app/models/handle.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07457"></a>T-07457 / [95](../../../test/models/handle_test.rb#L95) | "association deletion: restriction by active_avatars"<br>Owner: `HandleTest` | `assert_not @handle.destroy`; `assert @handle.errors[:base].any? { \|message\| message.include?("active avatars") }` | [AvatarCapability](../../../app/models/avatar_capability.rb#L12); [Handle](../../../app/models/handle.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-07458"></a>T-07458 / [108](../../../test/models/handle_test.rb#L108) | "public_id is a fixed 21-character NanoID"<br>Owner: `HandleTest` | `assert_public_id_fixed_length(::Handle)` | [Handle](../../../app/models/handle.rb#L31) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
