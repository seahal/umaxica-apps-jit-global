# Alloy overlay SELinux label: static check without container operations

- Date: 2026-10-12
- Commit: `ccceabd05d2e3a8f923ce398046f99d026a5b78e` (branch `feature`)
- Worktree: uncommitted changes present. The result below depends on one uncommitted line in
  `.devcontainer/compose.yaml`; `compose.yaml` and `podman/alloy/` had no uncommitted changes.
- Performed on the host checkout. No Podman command was run after the edit, and no container was
  restarted or recreated.

## Change checked

`.devcontainer/compose.yaml`, the `core` bind entry whose source is `./podman/alloy`:

```diff
         target: "/home/global/workspace/podman/alloy"
         read_only: true
         bind:
-          selinux: Z
+          selinux: z
```

`git diff --stat -- .devcontainer compose.yaml podman/alloy` reported one file, one insertion, one
deletion.

## Results

| Check                                                            | Result  |
| ---------------------------------------------------------------- | ------- |
| Diff is the single label line                                    | PASS    |
| Merged Compose render, `core` overlay entry                      | PASS    |
| Merged Compose render, `alloy` volumes unchanged                 | PASS    |
| Host SELinux state                                               | No SELinux |
| Alloy syntax validation of `podman/alloy/config.alloy` (MAIL-4)  | NOT_RUN |
| Effective read-only mount inside `core` (MAIL-5)                 | NOT_RUN |

### Merged Compose render

Command (exit code 0, empty stderr), using standalone `docker-compose` 5.5.1 as a file renderer and
`yq` 4.1.2 to extract entries; the full render was not retained because it can contain secrets:

```bash
docker-compose -f compose.yaml -f .devcontainer/compose.yaml config
```

`core` has exactly one entry targeting `/home/global/workspace/podman/alloy`: type `bind`, source
`<repository>/podman/alloy`, `read_only: true`, `bind.selinux: z`.

The other `core` bind entries are unchanged: `.` to `/home/global/workspace` (read-write, `Z`), and
`.github`, `bin`, `.devcontainer` (each `read_only: true`, `Z`).

`alloy` volumes: `<repository>/podman/alloy/config.alloy` to `/etc/alloy/config.alloy`
(`read_only: true`, `z`), named volume `alloy-volume` to `/var/lib/alloy/data`, and
`<repository>/log` to `/var/log/umaxica` (`read_only: true`, `z`).

### Host SELinux

`getenforce` is not installed and `/sys/fs/selinux` does not exist. On this host the `Z` and `z`
labels have no runtime effect; the edit aligns the declaration with the shared-source label that
`nine.md` Section 9.3 specifies.

## Not run

- Alloy syntax validation: the pinned `v1.19.2` binary is available only as a container image and
  the host has no `alloy` binary. Container operations were excluded from this check.
  `config.alloy` was not modified.
- Effective mount: `core` has not been recreated since the overlay was declared, so the overlay is
  not mounted in the running container. RW=false, readability from `core`, write refusal, and Alloy
  loading its config after recreation remain unverified until `core` is recreated.
