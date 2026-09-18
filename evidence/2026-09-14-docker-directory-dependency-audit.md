# 2026-09-14 `docker/` directory dependency audit

## Scope

Determine whether anything in the repository still depends on the legacy `docker/` directory, which
`plans/analysis/docker-to-podman-directory-migration.md` left in place after Step 2 (reference
switch to `podman/`, done 2026-08-10). Deletion was explicitly **not** in scope and was not
performed; `docker/` is retained until the migration is finished.

## Commands

```bash
grep -rn "docker/" --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=docker . \
  | grep -v "docker\.io" | grep -v "syntax=docker/"
grep -n "docker/" compose.yaml Containerfile .devcontainer/*
grep -rn "docker/" bin/
diff <(cd docker && find . -type f | sort) <(cd podman && find . -type f | sort)
git ls-files docker/ | wc -l
```

## Result

**No functional dependency on `docker/` remains.** `compose.yaml`, `Containerfile`,
`.devcontainer/`, and `bin/` contain no path reference into the directory once `docker.io` registry
references and `# syntax=docker/dockerfile:1` frontend directives are excluded. There is no build
context, bind mount, or `COPY` pointing at it.

The four surviving references are all exclusion rules — they keep `docker/` out of something rather
than depend on it:

| Location             | Line    | Purpose                          |
| -------------------- | ------- | -------------------------------- |
| `.containerignore`   | 129     | Excluded from the build context  |
| `.dockerignore`      | 143     | Excluded from the build context  |
| `.rubocop.yml`       | 1403    | `docker/**/*` lint exclusion     |
| `.gitignore`         | 118-120 | `core/preferences` ignore rules  |

`git ls-files docker/` reports 23 tracked files.

## One file is unique to `docker/`

A full recursive comparison of the two trees reports exactly one difference:

```
25d24
< ./tailscale/serve/serve.json
```

`docker/tailscale/serve/serve.json` has no counterpart under `podman/`. Every other file in
`docker/` exists under `podman/`. This matches
`notes/implementation/fakecloud-aws-development-baseline.md:117`, which records `docker/tailscale`
as the sole unique content. Step 3 of the migration must carry this file across before removing the
directory, or it is lost.

## Note on the migration's Step 3 precondition

Step 3 requires that `grep -rIn "docker/" --exclude-dir=.git .` report no remaining path references
into the directory. That condition is met apart from the four exclusion rules above, which the plan
already anticipates dropping as part of the same step.

## Not done

- `docker/` was not deleted.
- `docker/tailscale/serve/serve.json` was not copied to `podman/`.
- No `.containerignore`, `.dockerignore`, `.rubocop.yml`, or `.gitignore` entry was changed.
