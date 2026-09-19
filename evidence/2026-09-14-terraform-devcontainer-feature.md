# 2026-09-14 Terraform devcontainer feature added, and the claim that preceded it

## What was found

`terraform` was **not installed anywhere** in this repository's development environment, despite
four separate places stating it was. `.devcontainer/devcontainer.json` declared four features —
`github-cli`, `herdr`, `claude-code`, `codex` — and no Terraform among them.

Checked and found no Terraform installation path:

```bash
grep -rn "terraform" .devcontainer/ Containerfile compose.yaml compose.*.yaml
find . -name "devcontainer.json" -not -path "./node_modules/*"
ls mise.toml .tool-versions
```

No match in any container build or Compose file. The only application `devcontainer.json` is
`.devcontainer/devcontainer.json` (the rest are inside `vendor/bundle` gems). Neither `mise.toml`
nor `.tool-versions` exists.

## The four incorrect claims

| Location                                                     | Claim                                                    |
| ------------------------------------------------------------ | -------------------------------------------------------- |
| `notes/implementation/fakecloud-aws-development-baseline.md` | installed via `ghcr.io/devcontainers/features/terraform` |
| `docs/operations/fakecloud-migration-verification.md`        | "present since 2026-08-31" via that feature              |
| `terraform/environments/development/providers.tf`            | "now also installed inside `core`"                       |
| `adr/fakecloud-podman-staging-environment.md`                | that feature is the supported installation path          |

The first three predate this session. The fourth was written by the assistant earlier the same day,
carrying the existing documents forward without checking the file — the same mistake the other three
embody, repeated once more.

Notably, `docs/operations/fakecloud-migration-verification.md` correctly records that `podman`,
`docker`, and `aws` are absent from the `core` image, and singles out `terraform` as the one
exception that is present. That exception was the error.

## What was done

Added to `.devcontainer/devcontainer.json`:

```jsonc
"ghcr.io/devcontainers/features/terraform:1": {}
```

`//` comments are already used in that file (17 of them), so the JSONC comment accompanying the
entry matches existing style.

The four claims above were corrected in place rather than deleted, so the period during which the
documents and the container disagreed stays visible.

## Not verified

- **The feature has not been installed.** It takes effect on the next devcontainer rebuild, which
  has not happened. `terraform --version` has not been run anywhere.
- **No Terraform command has run.** `init`, `validate`, `plan`, `apply`, and `destroy` remain unrun
  against both `terraform/environments/development` and `staging-development`, exactly as
  `docs/operations/fakecloud-migration-verification.md` records.
- **No test covers this.** No file under `test/` reads `devcontainer.json`. A
  `DevelopmentContainerContractTest` that read it from the git index is referenced in
  `docs/operations/fakecloud-migration-verification.md`, and
  `test/tooling/vscode_podman_devcontainer_contract_test.rb` existed at the start of this session,
  but both are gone from the working tree — deleted by work running concurrently with this session,
  not by this change.

## Endpoint caveat for container-side runs

`terraform/environments/development/variables.tf` defaults `fakecloud_endpoint` to
`http://localhost:4566`, which is the loopback publication in `compose.yaml` and is correct only
when Terraform runs on the developer's host. Inside `core`, `localhost` is `core` itself, so runs
there must override it:

```bash
TF_VAR_fakecloud_endpoint=http://fakecloud:4566 terraform plan
```

Both `providers.tf` and `variables.tf` already documented this before the feature existed. The
default was left as-is: changing it would break the host path, and the override is one variable.
