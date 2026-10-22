# rails-services-avatar_social_graph: per-definition ledger

29 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/services/avatar_social_graph/block_test.rb`

[test/services/avatar_social_graph/block_test.rb](../../../test/services/avatar_social_graph/block_test.rb); SHA-256: `74b763321639e6d5c99ec94468cb0af9d7408fd641238720ef30bb6c5488f2f8`.

File-level implementation candidates (including setup/import context): [app/models/handle.rb:31](../../../app/models/handle.rb#L31); [app/services/avatar_social_graph.rb:53](../../../app/services/avatar_social_graph.rb#L53).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-11142"></a>T-11142 / [14](../../../test/services/avatar_social_graph/block_test.rb#L14) | "can block another avatar"<br>Owner: `AvatarSocialGraphBlockTest` | `assert_equal target, block.blocked_avatar`; `assert_includes actor.blocked_avatars, target` | [AvatarSocialGraph::Block](../../../app/services/avatar_social_graph.rb#L53) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11143"></a>T-11143 / [24](../../../test/services/avatar_social_graph/block_test.rb#L24) | "cannot block self"<br>Owner: `AvatarSocialGraphBlockTest` | `assert_raises(AvatarSocialGraph::SelfEdgeError) do` | [AvatarSocialGraph::SelfEdgeError](../../../app/services/avatar_social_graph.rb#L7) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11144"></a>T-11144 / [32](../../../test/services/avatar_social_graph/block_test.rb#L32) | "block is idempotent when already blocked"<br>Owner: `AvatarSocialGraphBlockTest` | `assert_equal existing.id, block.id` | [AvatarSocialGraph::Block](../../../app/services/avatar_social_graph.rb#L53) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11145"></a>T-11145 / [42](../../../test/services/avatar_social_graph/block_test.rb#L42) | "block terminates actor to target follow"<br>Owner: `AvatarSocialGraphBlockTest` | `assert_not_includes actor.followings, target` | [AvatarSocialGraph::Block](../../../app/services/avatar_social_graph.rb#L53) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11146"></a>T-11146 / [52](../../../test/services/avatar_social_graph/block_test.rb#L52) | "block terminates target to actor follow"<br>Owner: `AvatarSocialGraphBlockTest` | `assert_not_includes target.followings, actor` | [AvatarSocialGraph::Block](../../../app/services/avatar_social_graph.rb#L53) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11147"></a>T-11147 / [62](../../../test/services/avatar_social_graph/block_test.rb#L62) | "block does not remove mute"<br>Owner: `AvatarSocialGraphBlockTest` | `assert_includes actor.muted_avatars, target` | [AvatarSocialGraph::Block](../../../app/services/avatar_social_graph.rb#L53) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/services/avatar_social_graph/follow_test.rb`

[test/services/avatar_social_graph/follow_test.rb](../../../test/services/avatar_social_graph/follow_test.rb); SHA-256: `57dc8ba8f024a54c36f162bbc4a681d6ec7da30402ecd800623352913e011bb1`.

File-level implementation candidates (including setup/import context): [app/models/handle.rb:31](../../../app/models/handle.rb#L31); [app/services/avatar_social_graph.rb:11](../../../app/services/avatar_social_graph.rb#L11); [app/models/avatar_follow.rb:26](../../../app/models/avatar_follow.rb#L26); [app/models/actor.rb:16](../../../app/models/actor.rb#L16); [app/models/actor/authentication.rb:4](../../../app/models/actor/authentication.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-11148"></a>T-11148 / [14](../../../test/services/avatar_social_graph/follow_test.rb#L14) | "can follow another avatar"<br>Owner: `AvatarSocialGraphFollowTest` | `assert_equal target, follow.followed_avatar`; `assert_includes actor.followings, target` | [AvatarSocialGraph::Follow](../../../app/services/avatar_social_graph.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11149"></a>T-11149 / [24](../../../test/services/avatar_social_graph/follow_test.rb#L24) | "cannot follow self"<br>Owner: `AvatarSocialGraphFollowTest` | `assert_raises(AvatarSocialGraph::SelfEdgeError) do` | [AvatarSocialGraph::SelfEdgeError](../../../app/services/avatar_social_graph.rb#L7) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11150"></a>T-11150 / [32](../../../test/services/avatar_social_graph/follow_test.rb#L32) | "follow is idempotent when already following"<br>Owner: `AvatarSocialGraphFollowTest` | `assert_equal existing.id, follow.id`; `assert_equal 1, AvatarFollow.where(follower_avatar_id: actor.id, followed_avatar_id: target.id).count` | [AvatarSocialGraph::Follow](../../../app/services/avatar_social_graph.rb#L11); [AvatarFollow](../../../app/models/avatar_follow.rb#L26) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11151"></a>T-11151 / [43](../../../test/services/avatar_social_graph/follow_test.rb#L43) | "cannot follow an avatar that blocked actor"<br>Owner: `AvatarSocialGraphFollowTest` | `assert_raises(AvatarSocialGraph::BlockedError) do` | [Actor](../../../app/models/actor.rb#L16); [Actor](../../../app/models/actor/authentication.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11152"></a>T-11152 / [53](../../../test/services/avatar_social_graph/follow_test.rb#L53) | "cannot follow an avatar actor has blocked"<br>Owner: `AvatarSocialGraphFollowTest` | `assert_raises(AvatarSocialGraph::BlockedError) do` | [Actor](../../../app/models/actor.rb#L16); [Actor](../../../app/models/actor/authentication.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11153"></a>T-11153 / [63](../../../test/services/avatar_social_graph/follow_test.rb#L63) | "mute does not prevent follow"<br>Owner: `AvatarSocialGraphFollowTest` | `assert_includes actor.followings, target`; `assert_includes actor.muted_avatars, target` | [AvatarSocialGraph::Follow](../../../app/services/avatar_social_graph.rb#L11) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/services/avatar_social_graph/mute_test.rb`

[test/services/avatar_social_graph/mute_test.rb](../../../test/services/avatar_social_graph/mute_test.rb); SHA-256: `62b79f55ba482c19dd331402336d2435b110d893331a4586b904dac5d011eb43`.

File-level implementation candidates (including setup/import context): [app/models/handle.rb:31](../../../app/models/handle.rb#L31); [app/services/avatar_social_graph.rb:92](../../../app/services/avatar_social_graph.rb#L92).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-11154"></a>T-11154 / [14](../../../test/services/avatar_social_graph/mute_test.rb#L14) | "can mute another avatar"<br>Owner: `AvatarSocialGraphMuteTest` | `assert_equal target, mute.muted_avatar`; `assert_includes actor.muted_avatars, target` | [AvatarSocialGraph::Mute](../../../app/services/avatar_social_graph.rb#L92) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11155"></a>T-11155 / [24](../../../test/services/avatar_social_graph/mute_test.rb#L24) | "cannot mute self"<br>Owner: `AvatarSocialGraphMuteTest` | `assert_raises(AvatarSocialGraph::SelfEdgeError) do` | [AvatarSocialGraph::SelfEdgeError](../../../app/services/avatar_social_graph.rb#L7) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11156"></a>T-11156 / [32](../../../test/services/avatar_social_graph/mute_test.rb#L32) | "mute is idempotent when already muted"<br>Owner: `AvatarSocialGraphMuteTest` | `assert_equal existing.id, mute.id` | [AvatarSocialGraph::Mute](../../../app/services/avatar_social_graph.rb#L92) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11157"></a>T-11157 / [42](../../../test/services/avatar_social_graph/mute_test.rb#L42) | "mute does not remove follow"<br>Owner: `AvatarSocialGraphMuteTest` | `assert_includes actor.followings, target` | [AvatarSocialGraph::Mute](../../../app/services/avatar_social_graph.rb#L92) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11158"></a>T-11158 / [52](../../../test/services/avatar_social_graph/mute_test.rb#L52) | "mute does not create or remove block"<br>Owner: `AvatarSocialGraphMuteTest` | `assert_not_includes actor.blocked_avatars, target`; `assert_not_includes target.blocking_avatars, actor` | [AvatarSocialGraph::Mute](../../../app/services/avatar_social_graph.rb#L92) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/services/avatar_social_graph/unblock_test.rb`

[test/services/avatar_social_graph/unblock_test.rb](../../../test/services/avatar_social_graph/unblock_test.rb); SHA-256: `97226cb4fdfaca36c8fe24d68bb95add05a4906e41444f7bbc1fb4468ba38e9e`.

File-level implementation candidates (including setup/import context): [app/models/handle.rb:31](../../../app/models/handle.rb#L31); [app/services/avatar_social_graph.rb:144](../../../app/services/avatar_social_graph.rb#L144).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-11159"></a>T-11159 / [14](../../../test/services/avatar_social_graph/unblock_test.rb#L14) | "can unblock"<br>Owner: `AvatarSocialGraphUnblockTest` | `assert_not_includes actor.blocked_avatars, target` | [AvatarSocialGraph::Unblock](../../../app/services/avatar_social_graph.rb#L144) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11160"></a>T-11160 / [24](../../../test/services/avatar_social_graph/unblock_test.rb#L24) | "unblock is idempotent when no active block exists"<br>Owner: `AvatarSocialGraphUnblockTest` | `assert_nil AvatarSocialGraph::Unblock.call(actor_avatar: actor, target_avatar: target)` | [AvatarSocialGraph::Unblock](../../../app/services/avatar_social_graph.rb#L144) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11161"></a>T-11161 / [31](../../../test/services/avatar_social_graph/unblock_test.rb#L31) | "unblock does not restore prior follow state"<br>Owner: `AvatarSocialGraphUnblockTest` | `assert_not_includes actor.followings, target` | [AvatarSocialGraph::Block](../../../app/services/avatar_social_graph.rb#L53) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11162"></a>T-11162 / [42](../../../test/services/avatar_social_graph/unblock_test.rb#L42) | "unblock does not remove mute"<br>Owner: `AvatarSocialGraphUnblockTest` | `assert_includes actor.muted_avatars, target` | [AvatarSocialGraph::Unblock](../../../app/services/avatar_social_graph.rb#L144) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/services/avatar_social_graph/unfollow_test.rb`

[test/services/avatar_social_graph/unfollow_test.rb](../../../test/services/avatar_social_graph/unfollow_test.rb); SHA-256: `e75ccd0feb32cffaa2b445ce741a31aba24a120037f0901068bd89bc3ae016fb`.

File-level implementation candidates (including setup/import context): [app/models/handle.rb:31](../../../app/models/handle.rb#L31); [app/services/avatar_social_graph.rb:124](../../../app/services/avatar_social_graph.rb#L124).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-11163"></a>T-11163 / [14](../../../test/services/avatar_social_graph/unfollow_test.rb#L14) | "can unfollow an active follow"<br>Owner: `AvatarSocialGraphUnfollowTest` | `assert_not_includes actor.followings, target` | [AvatarSocialGraph::Unfollow](../../../app/services/avatar_social_graph.rb#L124) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11164"></a>T-11164 / [24](../../../test/services/avatar_social_graph/unfollow_test.rb#L24) | "unfollow is idempotent when no active follow exists"<br>Owner: `AvatarSocialGraphUnfollowTest` | `assert_nil AvatarSocialGraph::Unfollow.call(actor_avatar: actor, target_avatar: target)` | [AvatarSocialGraph::Unfollow](../../../app/services/avatar_social_graph.rb#L124) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11165"></a>T-11165 / [31](../../../test/services/avatar_social_graph/unfollow_test.rb#L31) | "unfollow does not remove mute"<br>Owner: `AvatarSocialGraphUnfollowTest` | `assert_includes actor.muted_avatars, target` | [AvatarSocialGraph::Unfollow](../../../app/services/avatar_social_graph.rb#L124) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11166"></a>T-11166 / [42](../../../test/services/avatar_social_graph/unfollow_test.rb#L42) | "unfollow does not remove block"<br>Owner: `AvatarSocialGraphUnfollowTest` | `assert_includes actor.blocked_avatars, target` | [AvatarSocialGraph::Unfollow](../../../app/services/avatar_social_graph.rb#L124) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/services/avatar_social_graph/unmute_test.rb`

[test/services/avatar_social_graph/unmute_test.rb](../../../test/services/avatar_social_graph/unmute_test.rb); SHA-256: `e47cef9a7c9ff6258d71cae5de48aaf1b001b34a75b1481f770c499a4338902e`.

File-level implementation candidates (including setup/import context): [app/models/handle.rb:31](../../../app/models/handle.rb#L31); [app/services/avatar_social_graph.rb:164](../../../app/services/avatar_social_graph.rb#L164).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-11167"></a>T-11167 / [14](../../../test/services/avatar_social_graph/unmute_test.rb#L14) | "can unmute"<br>Owner: `AvatarSocialGraphUnmuteTest` | `assert_not_includes actor.muted_avatars, target` | [AvatarSocialGraph::Unmute](../../../app/services/avatar_social_graph.rb#L164) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11168"></a>T-11168 / [24](../../../test/services/avatar_social_graph/unmute_test.rb#L24) | "unmute is idempotent when no active mute exists"<br>Owner: `AvatarSocialGraphUnmuteTest` | `assert_nil AvatarSocialGraph::Unmute.call(actor_avatar: actor, target_avatar: target)` | [AvatarSocialGraph::Unmute](../../../app/services/avatar_social_graph.rb#L164) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11169"></a>T-11169 / [31](../../../test/services/avatar_social_graph/unmute_test.rb#L31) | "unmute does not remove follow"<br>Owner: `AvatarSocialGraphUnmuteTest` | `assert_includes actor.followings, target` | [AvatarSocialGraph::Unmute](../../../app/services/avatar_social_graph.rb#L164) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-11170"></a>T-11170 / [42](../../../test/services/avatar_social_graph/unmute_test.rb#L42) | "unmute does not remove block"<br>Owner: `AvatarSocialGraphUnmuteTest` | `assert_includes actor.blocked_avatars, target` | [AvatarSocialGraph::Unmute](../../../app/services/avatar_social_graph.rb#L164) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
