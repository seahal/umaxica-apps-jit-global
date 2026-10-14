# Routing annotations — Step 16

Recorded 2026-10-13 against full HEAD
`aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`, branch `feature`. The worktree remained extensively
dirty; unrelated changes were preserved.

Updated only the FIXME comment for Base's Edge token-management namespace in
`config/routes/base.rb`. It now states the review direction, the client-compatibility risk and the
owning routing ADR. Existing `param:` debt annotations already use the required `[routing]` form.
The active route inventory contains 13 such `param:` declarations and 14 `[routing]` FIXME groups
including the Base Edge namespace. `bin/rails notes --annotations FIXME` listed the new Base
comment.

Before and after route listings used the same development settings:
`UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example RUBY_DEBUG_ENABLE=0 bin/rails routes`.
After removing startup INFO lines and normalizing process-specific `0x...` object addresses, both
route listings had 1,676 lines and the same SHA-256:
`97effbaa2a6112a15ac55bf2387bafaacc3085a179e929c255ddb85cb18ac1a5`. The normalized diff was
empty, so methods, paths, actions, helpers and order did not change. RuboCop passed for
`config/routes/base.rb`, and `git diff --check` passed. No behavior test was added because this step
changed comments only.
