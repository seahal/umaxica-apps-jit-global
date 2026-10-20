# Parent Deletion Policy Redesign (MissingDependentDestroyChecker)

Recorded 2026-10-20. Status: backlog, redesign required.

## Problem

`database_consistency` reports 222 `MissingDependentDestroyChecker` findings. For each child
`belongs_to`, the checker accepts only a parent association with `dependent: :destroy`, `:delete`,
`:delete_all` or `:nullify`, or a foreign key with `ON DELETE CASCADE` or `SET NULL`. It does not
accept the current protection, a `RESTRICT` foreign key or `dependent: :restrict_with_exception`,
which refuses parent deletion while children exist. Configuration-file exclusions are not allowed.

Adding an accepted option changes behavior from "refuse to delete the parent" to "delete or nullify
the children". On 2026-10-20, adding `has_many ..., dependent: :delete_all` to
`Publishing::MediaFile` was tried in a temporary test. Destroying a media file used by a revision
used to raise from the RESTRICT key. With the change it succeeded and silently removed the
revision's usage rows (`evidence/2026-10-20-model-validation-and-check-constraints-V5T3.md`). The
user decided on 2026-10-20 that this group needs a real redesign, not a mechanical fix.

## Findings by association (2026-10-20)

| Child association                                                                                                                                                                                       | Count | Notes                                                      |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----: | ---------------------------------------------------------- |
| `vocabulary`, `taxonomy_term` (Publishing taxonomy assignments)                                                                                                                                         |    96 | Parents refuse every delete through BEFORE DELETE triggers |
| `media_file` (revision/version media usages)                                                                                                                                                            |    24 | Deleting a used file must not drop content references      |
| `restored_from_version`, `restored_from_revision`, `entry_revision`, `current_revision`                                                                                                                 |    48 | Publishing revision and version history                    |
| `sign_in_flow`, `secret_sign_in_flow`, `step_up_ceremony_transaction`, `oidc_authorization_transaction`, `authorization_transaction`, `auth_ceremony_session`, `base_token`, `client_token`, `issuance` |    23 | Authentication flow and token references                   |
| `status`, `from_status`, `lifecycle_state`                                                                                                                                                              |     9 | Status reference rows                                      |
| `source_ownership_period`, `source_*`, `target_operator`, `visitor`, `user`, `staff`, `client`                                                                                                          |    22 | Ownership and actor references                             |

## Redesign questions

For each parent, decide and record:

1. Can this parent ever be deleted? If never, make that explicit and enforced (as the taxonomy
   triggers do). Decide how to represent it without adding a dependent option that never runs.
2. If it can be deleted, what happens to the children: delete them with the parent, keep them with
   an explicit retained state, or refuse? Apply the `AGENTS.md` rules on audit history, and the rule
   against giving NULL a meaning, so that nullify does not turn NULL into a state.
3. Whether the checker's model fits this application. If RESTRICT is the right answer, record why in
   an ADR before changing any code.

## Work rules

Write characterization tests for each deletion path first, change one parent family at a time,
accept only intended behavior changes, and record each result in `evidence/`.
