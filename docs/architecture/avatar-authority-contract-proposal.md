# Avatar Authority HTTPS Contract (R5-WU14) — S Proposal

Status: **Approved by the user on 2026-10-17 (S) as written; the same pattern applies to R5-WU12 and
R5-WU15.** (one.md 6.4: domain routes and schemas other than Publishing are fixed in their owning
unit and need a reviewed Before/After sample).

## Before

Base app/org pages (Self-RP cells `base-app-ww`, `base-org-ww`) call Avatar Operations and read the
`avatar` store in-process with the Global actor (`current_client` / `current_operator`), the OP
grant as `current_session` (selected collective) and `Actor.selection` (selected persona).

## After (proposed)

Server-to-server, same pattern as Publishing (R5-WU13): the Base RP sends its private_key_jwt bound
to the exact URL and the actor's Access JWT. Base reads the selected context from its RP session and
sends the Persona, organization and unit public IDs. APP reads the Avatar ID from its RP session
selection row; ORG reads the optional Avatar ID from a child row keyed to the RP session's actor
selection. No child row means no Avatar is selected. The Avatar owner re-resolves the real actor
from the Access Token and matches the complete tuple against candidates the actor may select; it
never reads selection from the OP root or trusts the supplied IDs by themselves. The RP session
remains the sole Base APP/ORG selection writer. Both surfaces then apply the existing `AvatarPolicy` /
`AvatarPermissionResolver` / ownership-period checks and Operations. Answers are allowlisted JSON.
The former APP `GET /api/v0/identity/selection` root-token reader returns `409` and exposes no
competing selection.

Base path: `/api/v0/avatar/:surface` (`surface` = `app` | `org`), on the realm Base host.

| Existing action                                      | Proposed route                                              | Request                                                 | Response                                                  |
| ---------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------- | --------------------------------------------------------- |
| avatars#index                                        | `GET /avatars?persona=<public_id>`                          | —                                                       | `{"avatars":[{"public_id","moniker"}],"can_create":bool}` |
| avatars#show                                         | `GET /avatars/:avatar_ref?persona=`                         | —                                                       | `{"avatar":{"public_id","moniker","handle"}}`             |
| avatars#create (app)                                 | `POST /avatars`                                             | `{"persona":"…","avatar":{"moniker":"…","handle":"…"}}` | 201 avatar / 422 `{"errors":{"avatar.moniker":…}}` / 403  |
| avatars#update                                       | `PATCH /avatars/:avatar_ref`                                | `{"persona":"…","avatar":{"moniker":"…"}}`              | 200 / 422 / 403                                           |
| avatars#destroy (org)                                | `DELETE /avatars/:avatar_ref`                               | `{"persona":"…"}`                                       | 200 / 403                                                 |
| avatar_ownership_transfers#create                    | `POST /avatars/:avatar_ref/ownership-transfers`             | existing transfer form fields                           | 201 / 422 / 403                                           |
| follows/blocks/mutes#create,destroy (app)            | `POST`/`DELETE /avatars/:avatar_ref/{follows,blocks,mutes}` | `{"persona":"…","target":"<avatar public_id>"}`         | 200 / 403 / 404                                           |
| group_avatar_memberships#create,update,destroy (app) | `/groups/:group_ref/avatar-memberships[/:ref]`              | existing form fields                                    | 200/201 / 422 / 403                                       |
| groups#index,show,create,update,destroy (app)        | `/groups[/:group_ref]`                                      | existing form fields                                    | as above                                                  |
| dashboard_avatar_images#show                         | `GET /avatars/:avatar_ref/image`                            | —                                                       | image bytes or 404 (no Avatar rows)                       |
| switchers#show,update (org)                          | `GET`/`PUT /switcher`                                       | `{"avatar":"<public_id>"}`                              | current selection / 403                                   |

Invariants kept at the owner: ownership-period lock and "owner changed while updating" refusal; one
active Avatar per persona (409/422 under `avatar`); owner-surface checks; collective membership via
`AvatarOwnerMembershipLockService`; no new permission (D-10 deferred work stays unimplemented).
Writes are not blindly retried; an indeterminate write is re-read.

## Questions resolved on 2026-11-05

1. APP and ORG Base selection is owned by the corresponding Base RP session. The owner receives the
   selected tuple and validates it against the authenticated actor's candidates before applying
   Avatar policies.
2. Serving private image bytes through the Avatar API remains accepted as specified above.
3. ORG's RP-local actor selection stores account, organization and unit; its optional Avatar context
   is stored in `rp_base_org_session_avatar_selections`, with one NOT NULL Avatar ID per selected
   actor session. The actor and Avatar selection writes share the RP session lock.
