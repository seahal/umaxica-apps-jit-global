#!/usr/bin/env bash
# Host-side checks for the Tailscale remote-access overlay, run before
# `podman compose -f compose.yaml -f .devcontainer/compose.yaml \
#  -f compose.override.yaml --profile remote-access up`. The middle file is where
# `core` is defined; the last one carries the profile-gated sshd overlay.
#
# Identical in umaxica-apps-global, umaxica-apps-edge and portal except for the
# compose project name, the tailnet hostname, and the document it points at.
#
# Everything here fails inside the container too, eventually. It is checked out
# here because at this point the reason is still on screen, rather than in the
# logs of a container that came up looking healthy and is simply unreachable.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

authorized_keys=.secrets/codex_authorized_keys
state_volume=umaxica-apps-global-dc_tailscale-state
doc=docs/operations/remote-codex-over-tailscale.md

fail() {
  echo "remote-access preflight: $1" >&2
  shift
  for line in "$@"; do echo "  ${line}" >&2; done
  exit 78
}

# 1. The public key sshd will accept.
[[ -f ${authorized_keys} ]] ||
  fail "${authorized_keys} does not exist." \
    "Create it and add the public key Codex App connects with:" \
    "  install -m 0600 -D /dev/null ${authorized_keys}" \
    "  cat ~/.ssh/id_ed25519.pub >> ${authorized_keys}"

[[ -s ${authorized_keys} ]] ||
  fail "${authorized_keys} is empty." \
    "sshd would start and accept no login at all. Add the client's PUBLIC key."

grep -Eq '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-|sk-ssh-ed25519@|sk-ecdsa-sha2-)' "${authorized_keys}" ||
  fail "${authorized_keys} contains no recognisable public key line." \
    "A private key or a stray comment here is a silent no-login."

if grep -q 'PRIVATE KEY' "${authorized_keys}"; then
  fail "${authorized_keys} contains a PRIVATE key." \
    "Only the .pub half belongs here. Remove it and rotate that key."
fi

if [[ $(( 0$(stat -c %a "${authorized_keys}") & 0022 )) -ne 0 ]]; then
  fail "${authorized_keys} is group- or other-writable." \
    "sshd's StrictModes refuses it. Run: chmod 0600 ${authorized_keys}"
fi

# 2. The auth key, which must be present exactly once in this node's lifetime.
#
# Reading .env rather than only the environment: that is where the key is put,
# and the whole point of this check is to notice one that was left behind.
env_key=''
if [[ -f .env ]]; then
  env_key=$(sed -n 's/^TS_AUTHKEY=//p' .env | tail -n 1)
fi
authkey="${TS_AUTHKEY:-${env_key}}"

if podman volume exists "${state_volume}" 2> /dev/null; then
  # Enrolled already. A key still lying around is a long-lived credential in a
  # file, for no remaining purpose -- which is the exact thing the one-off key
  # procedure exists to avoid. Refusing to start is what makes "delete it
  # afterwards" an actual step rather than a sentence in a document.
  if [[ -n ${authkey} ]]; then
    fail "TS_AUTHKEY is still set, but umaxica-global-core is already enrolled." \
      "The key was single-use and is now only a credential sitting in a file." \
      "Revoke it in the Tailscale admin console, then remove the line:" \
      "  sed -i '/^TS_AUTHKEY=/d' .env" \
      "Persisted state in ${state_volume} is all this node needs from here on." \
      "See ${doc}."
  fi
else
  # Not enrolled. Without a key tailscaled starts, fails to authenticate, and
  # retries -- reachable nowhere, explained only in its own log.
  if [[ -z ${authkey} ]]; then
    fail "first remote-access start needs a one-off TS_AUTHKEY." \
      "Mint one that is one-off, tagged tag:umaxica-devcontainer, pre-approved," \
      "and NOT ephemeral -- an ephemeral node is deleted when the container" \
      "stops, discarding the identity this design is built on." \
      "  echo 'TS_AUTHKEY=tskey-auth-...' >> .env" \
      "See ${doc}."
  fi
fi

# 3. .env must not be tracked. It holds the key for the length of one bootstrap,
#    and a repository that would commit it turns a single-use key into a
#    published one.
if [[ -f .env ]] && git ls-files --error-unmatch .env > /dev/null 2>&1; then
  fail ".env is tracked by git." \
    "TS_AUTHKEY goes there during bootstrap. Untrack it before continuing:" \
    "  git rm --cached .env"
fi

echo 'remote-access preflight: ok' >&2
