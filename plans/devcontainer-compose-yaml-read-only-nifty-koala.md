# Remove the three remaining Xper aliases from `.devcontainer/compose.yaml`

## Context

Step 5 (Xper surface retirement) is in progress in the worktree. The handoff note `six.md` records
that the executing agent could not remove the last three Xper entries from
`.devcontainer/compose.yaml` because the file was read-only for it.

The cause is the mount, not the file. `.devcontainer/compose.yaml` lines 122–127 bind `./.devcontainer`
into `core` at `/home/global/workspace/.devcontainer` with `read_only: true`, so any agent working
inside the container cannot write there. On the host the same file is an ordinary writable file
(`-rw-r--r-- mslo:mslo`, no immutable attribute, no uncommitted diff). The read-only mount is a
deliberate guard and stays as it is; the edit is simply made from the host checkout.

## Change

One file, three deleted lines, in `services.core.networks.frontend.aliases`
(`.devcontainer/compose.yaml` lines 162–164):

```yaml
          - xper.app.localhost
          - xper.com.localhost
          - xper.org.localhost
```

Everything else is preserved: the preceding `core-workers-vpc.internal`, the following
`base.app.localhost`, and every other alias. The file has no `PUBLIC_XPER_*` / `PRIVATE_XPER_*`
entries, so nothing else in it needs to change.

Out of scope, left untouched:

- the `read_only: true` mount itself;
- the rest of the uncommitted Step 5 worktree changes, which belong to the other session;
- `test/integration/xper_retired_hosts_test.rb`, which lists the same three hostnames on purpose as
  retired hosts;
- `six.md` (Git-ignored handoff note owned by the other session);
- any commit — Step 5 is committed by its owner only once its verification is complete.

## Effect on the running stack

No build, no `compose up`, no container restart or recreation. The bind mount makes the edited file
visible inside `core` immediately. The network aliases of the running `core` container are fixed at
creation time, so the three names keep resolving on the `frontend` network until `core` is next
recreated for some other reason; nothing is forced now.

## Verification

- `grep -niE 'xper' .devcontainer/compose.yaml` returns nothing.
- `git diff -- .devcontainer/compose.yaml` shows exactly three deleted lines.
- Parse the file as YAML with Ruby (`ruby -ryaml -e 'YAML.load_file(...)'`) and confirm the alias
  list still starts with `core-workers-vpc.internal`, `base.app.localhost`.
- `podman exec global-devcontainer-core grep -c xper /home/global/workspace/.devcontainer/compose.yaml`
  reports 0, confirming the in-container view picked the edit up (read-only command, no restart).

The retired-host integration test and the twelve shared selectors remain blocked by the separate
test-database preparation issue described in `six.md`; this change does not address that.
