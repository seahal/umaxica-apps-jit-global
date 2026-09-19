#!/usr/bin/env bash
# `core`'s main process under `compose.override.yaml`'s `remote-access` profile.
#
# Identical in umaxica-apps-global, umaxica-apps-edge and portal except for the
# account name and its home. Change one, change all three.
#
# Runs as `global`. Prepares the persistent host key, refuses to start without
# authorized keys, then execs sshd in the foreground so the container's restart
# policy and `podman logs` both see the real process rather than a wrapper.
set -euo pipefail

config=/etc/ssh/remote-sshd_config
state_dir=/home/global/.local/state/remote-sshd
host_key=${state_dir}/ssh_host_ed25519_key
authorized_keys=/home/global/.config/umaxica/authorized_keys

# An sshd with no keys accepts no logins, but starts and logs nothing unusual --
# it looks identical to a working server until the first connection attempt
# fails. Fail here instead, where the reason is one `podman logs` away.
if [[ ! -s ${authorized_keys} ]]; then
  echo "remote-sshd: ${authorized_keys} is missing or empty." >&2
  echo 'compose.override.yaml binds it read-only from .secrets/codex_authorized_keys' >&2
  echo 'in the repository. Put the public key Codex App connects with there, then' >&2
  echo 'recreate core. See the remote-access document for the full procedure.' >&2
  exit 78
fi

# StrictModes rejects these too, but per connection and only in sshd's own log.
# Naming it at startup keeps a mis-moded bind mount a visible failure.
if [[ $(( 0$(stat -c %a "${authorized_keys}") & 0022 )) -ne 0 ]]; then
  echo "remote-sshd: ${authorized_keys} is group- or other-writable; sshd will refuse it." >&2
  exit 78
fi

# 0700 because sshd's own strict-mode check walks the host key's parent, and
# because a Podman named volume is created 0755 by default.
mkdir -p "${state_dir}"
chmod 0700 "${state_dir}"

# Generated once, never baked into an image layer, never printed. Regenerating on
# each start would change the fingerprint and make every configured client refuse
# the connection.
if [[ ! -f ${host_key} ]]; then
  echo 'remote-sshd: generating the persistent ed25519 host key (first start only).' >&2
  ssh-keygen -q -t ed25519 -N '' -C 'umaxica-apps-global core' -f "${host_key}"
fi
chmod 0600 "${host_key}"
[[ -f ${host_key}.pub ]] && chmod 0644 "${host_key}.pub"

# sshd builds each session's environment from scratch. It inherits nothing from
# this process, which means an SSH login sees none of the variables Compose sets
# on the service -- the database URLs, the PUBLIC_*/PRIVATE_* host tables, the
# OTEL endpoints -- while `podman exec` and the devcontainer terminal see all of
# them. `bin/rails` then fails over SSH and works everywhere else, which reads as
# a broken container rather than as a missing environment.
#
# `SetEnv` in the config covers the toolchain paths, but it is a static list and
# cannot carry a service environment that changes with compose.yaml. Snapshot the
# real one instead, from this process -- which IS the container's environment,
# because it is the container's main process.
#
# Excluded: the per-session variables sshd sets correctly by itself (a snapshot
# of PATH or HOME here would override the SetEnv line and the session's own
# values), and names that are not valid shell identifiers.
session_env=/run/sshd/session-env.sh
(
  # Scoped to the subshell: sshd sets its own umask for user sessions, but
  # leaving 077 in the exec'd process's inherited state is a side effect nothing
  # here asked for.
  umask 077
{
  echo '# Generated at container start by remote-sshd-entrypoint. Do not edit:'
  echo '# it is overwritten on every start, and read by every SSH session.'
  while IFS='=' read -r -d '' name value; do
    case ${name} in
      '' | *[!A-Za-z0-9_]* | [0-9]*) continue ;;
      PATH | HOME | USER | LOGNAME | SHELL | PWD | OLDPWD | SHLVL | TERM | _ ) continue ;;
      BASH_ENV | SSH_* | LS_COLORS ) continue ;;
    esac
    printf 'export %s=%q\n' "${name}" "${value}"
  done < /proc/self/environ

  # PATH is exported too, and it is the reason this file matters for login
  # shells specifically: /etc/profile assigns PATH outright, so a login shell
  # discards whatever `SetEnv PATH` gave the session and ends up with the
  # system default -- no pnpm, no user-local bin. Re-exporting it here, after
  # /etc/profile has run, is what makes an interactive login and a bare
  # `ssh host cmd` agree. The prefix is the same one the SetEnv line carries.
  printf 'export PATH=%q\n' "/home/global/.local/bin:/usr/local/bundle/bin:${PATH}"
} > "${session_env}"
)

# Where that file gets read from is the fiddly part, and it is worth writing down
# because two obvious answers are both wrong.
#
# BASH_ENV is not it. Bash detects when it was started by sshd with stdin on a
# socket, and in that case reads ~/.bashrc INSTEAD of BASH_ENV -- so
# `ssh host cmd`, the shape every Remote-SSH agent uses, never looks at it. It
# stays on the SetEnv line only for shells started some other way.
#
# Appending to ~/.bashrc is not it either. Debian's stock ~/.bashrc opens with
#
#     case ehuB in *i*) ;; *) return;; esac
#
# so a line at the END of the file is unreachable for exactly the non-interactive
# case that needed it. Hence PREPEND: the source line has to run before that
# guard. Interactive shells and login shells reach it too -- Debian's ~/.profile
# sources ~/.bashrc unconditionally for bash -- so one insertion covers all three
# shell shapes.
#
# The marker makes this idempotent; without it the block accumulates once per
# container start for the life of the home directory.
bashrc=/home/global/.bashrc
marker='# >>> remote-sshd session environment >>>'
if ! grep -qF "${marker}" "${bashrc}" 2> /dev/null; then
  tmp=$(mktemp "${bashrc}.XXXXXX")
  {
    echo "${marker}"
    echo "# Prepended by remote-sshd-entrypoint. Must stay ABOVE the stock"
    echo "# non-interactive guard below, or \`ssh host cmd\` gets none of it."
    echo "[ -r ${session_env} ] && . ${session_env}"
    echo '# <<< remote-sshd session environment <<<'
    [[ -f ${bashrc} ]] && cat "${bashrc}"
  } > "${tmp}"
  chmod --reference="${bashrc}" "${tmp}" 2> /dev/null || chmod 0644 "${tmp}"
  mv "${tmp}" "${bashrc}"
fi

# Fail before forking rather than after, so a bad edit to the config is an
# immediate, readable startup error.
/usr/sbin/sshd -t -f "${config}"

# Tailscale, in this container rather than a sidecar: tailscaled joins the
# tailnet in userspace-networking mode, which runs as `global` with no
# /dev/net/tun, no NET_ADMIN and no new privileges — the same posture the
# sidecar had. Its netstack terminates tailnet connections and dials sshd over
# loopback, so sshd no longer needs to be reachable from any other container.
#
#   client --- tailnet tcp/22 ---> tailscaled (this container) --- 127.0.0.1:2222 ---> sshd
#
# State (the node identity) lives on the tailscale-state volume mounted here;
# losing it forces a fresh enrolment and drifts the tailnet name. The daemon is
# backgrounded and sshd stays the exec'd main process; the init reaper collects
# it, and its log goes to stderr where `podman logs` already looks.
ts_state=/home/global/.local/state/tailscale
ts_socket=${ts_state}/tailscaled.sock
/usr/sbin/tailscaled \
  --tun=userspace-networking \
  --statedir="${ts_state}" \
  --socket="${ts_socket}" &

# The socket appears asynchronously; every `tailscale` call below needs it.
for _ in $(seq 1 50); do
  [[ -S ${ts_socket} ]] && break
  sleep 0.2
done
[[ -S ${ts_socket} ]] || { echo 'remote-sshd: tailscaled did not come up.' >&2; exit 69; }

# `up` only while enrolling. TS_AUTHKEY is single-use and present exactly once
# (remote-access-preflight.sh enforces both directions); on every later start
# the persisted state is enough and tailscaled reconnects by itself. The flags
# mirror what the sidecar passed: the shared devcontainer tag (one ACL grant,
# no user key expiry) and no tailnet DNS (accepting it would replace this
# container's resolver).
if [[ -n ${TS_AUTHKEY:-} ]]; then
  echo 'remote-sshd: enrolling in the tailnet (first start only).' >&2
  /usr/bin/tailscale --socket="${ts_socket}" up \
    --authkey="${TS_AUTHKEY}" \
    --hostname=umaxica-global-core \
    --advertise-tags=tag:umaxica-devcontainer \
    --accept-dns=false
fi

# Tailnet tcp/22 -> sshd, replacing the sidecar's serve.json. Clients keep
# connecting to port 22 while sshd keeps its unprivileged 2222. The config
# persists in the state volume, and re-declaring the same forward is a no-op,
# so running it every start keeps the file the source of truth.
/usr/bin/tailscale --socket="${ts_socket}" serve --bg --tcp=22 tcp://127.0.0.1:2222

# The fingerprint clients must expect. Printed once at startup so setting up
# known_hosts does not require a second command.
ssh-keygen -lf "${host_key}.pub" >&2

# -D keeps sshd in the foreground under the init reaper; -e sends its log to
# stderr so authentication failures land in `podman logs` rather than in a syslog
# socket this container does not have.
exec /usr/sbin/sshd -D -e -f "${config}"
