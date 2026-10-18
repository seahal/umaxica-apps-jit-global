#!/bin/bash -p
set -uo pipefail

# Virtual desktop for the development container:
#
#   Chromium / Playwright -> Xvfb -> x11vnc -> websockify + noVNC -> host loopback
#
# See docs/operations/development-browser-desktop.md.

readonly PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
unset BASH_ENV ENV CDPATH

readonly DESKTOP_DISPLAY=:99
readonly DESKTOP_DISPLAY_NUMBER=99
readonly DESKTOP_SCREEN=1440x900x24
readonly VNC_PORT=5900
readonly NOVNC_PORT=6080
readonly NOVNC_WEB_ROOT=/usr/share/novnc
readonly STATE_DIR="${HOME:?HOME must be set}/.local/state/desktop"
readonly PASSWORD_FILE="${STATE_DIR}/vnc-password"
readonly COMPONENTS=(Xvfb openbox x11vnc websockify)

log() {
  printf 'core-desktop: %s\n' "$*" >&2
}

pid_file() {
  printf '%s/%s.pid' "${STATE_DIR}" "$1"
}

# A pidfile outlives the container's processes across `podman restart`, and the
# recorded PID can then belong to an unrelated process. The command name is
# compared as well so a reused PID is never mistaken for the component.
component_pid() {
  local name=$1
  local pid

  [[ -r "$(pid_file "${name}")" ]] || return 1
  pid=$(<"$(pid_file "${name}")")
  [[ "${pid}" =~ ^[0-9]+$ ]] || return 1
  [[ -r "/proc/${pid}/cmdline" ]] || return 1
  tr '\0' ' ' <"/proc/${pid}/cmdline" | grep -q -- "${name}" || return 1
  printf '%s' "${pid}"
}

spawn() {
  local name=$1
  shift

  # Own session: these outlive the shell that started them and are reaped by
  # the container's init, not by this script.
  setsid "$@" >>"${STATE_DIR}/${name}.log" 2>&1 </dev/null &
  printf '%s\n' "$!" >"$(pid_file "${name}")"
  log "started ${name} (pid $!)"
}

wait_for() {
  local description=$1
  local attempts=50
  shift

  while (( attempts > 0 )); do
    if "$@" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
    attempts=$((attempts - 1))
  done

  log "timed out waiting for ${description}; see ${STATE_DIR}"
  return 1
}

listening_on() {
  ss -ltn "sport = :$1" | grep -q LISTEN
}

ensure_password() {
  [[ -s "${PASSWORD_FILE}" ]] && return 0

  # RFB authentication uses at most eight characters. The value is written
  # straight to a 0600 file and handed to x11vnc by path, so it never appears
  # in a process argument list or a log.
  (umask 077 && openssl rand -hex 4 >"${PASSWORD_FILE}") || {
    log "could not generate the VNC password"
    return 1
  }
}

start_xvfb() {
  component_pid Xvfb >/dev/null && return 0

  # Left behind by a previous container run; Xvfb refuses to start over them.
  rm -f "/tmp/.X${DESKTOP_DISPLAY_NUMBER}-lock" "/tmp/.X11-unix/X${DESKTOP_DISPLAY_NUMBER}"
  spawn Xvfb Xvfb "${DESKTOP_DISPLAY}" -screen 0 "${DESKTOP_SCREEN}" -nolisten tcp
  wait_for "the X display" test -S "/tmp/.X11-unix/X${DESKTOP_DISPLAY_NUMBER}"
}

start_openbox() {
  component_pid openbox >/dev/null && return 0

  DISPLAY=${DESKTOP_DISPLAY} spawn openbox openbox
}

start_x11vnc() {
  component_pid x11vnc >/dev/null && return 0

  ensure_password || return 1
  # `-localhost`: the RFB port is for websockify in this container only and is
  # never published.
  spawn x11vnc x11vnc -display "${DESKTOP_DISPLAY}" -rfbport "${VNC_PORT}" -localhost \
    -passwdfile "${PASSWORD_FILE}" -forever -shared -quiet
  wait_for "the VNC server" listening_on "${VNC_PORT}"
}

start_websockify() {
  component_pid websockify >/dev/null && return 0

  # Binds every container interface, like Rails does: Podman forwards a
  # published port to the container's network address, never to its loopback.
  # Host exposure is decided by the loopback-only `ports:` entry, see
  # docs/operations/development-host-port-exposure.md.
  spawn websockify websockify --web "${NOVNC_WEB_ROOT}" "0.0.0.0:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}"
  wait_for "noVNC" listening_on "${NOVNC_PORT}"
}

start() {
  local status=0

  mkdir -p "${STATE_DIR}" && chmod 0700 "${STATE_DIR}" || return 1

  # Serialized so two concurrent starts cannot both see "not running".
  exec 9>"${STATE_DIR}/lock"
  flock 9

  start_xvfb && start_openbox && start_x11vnc && start_websockify || status=$?

  flock -u 9
  exec 9>&-
  return "${status}"
}

stop() {
  local name pid index

  for (( index = ${#COMPONENTS[@]} - 1; index >= 0; index-- )); do
    name=${COMPONENTS[index]}
    if pid=$(component_pid "${name}"); then
      kill -TERM "${pid}" 2>/dev/null && log "stopped ${name} (pid ${pid})"
    fi
    rm -f "$(pid_file "${name}")"
  done
}

status() {
  local name pid result=0

  for name in "${COMPONENTS[@]}"; do
    if pid=$(component_pid "${name}"); then
      printf '%-10s running (pid %s)\n' "${name}" "${pid}"
    else
      printf '%-10s stopped\n' "${name}"
      result=1
    fi
  done

  return "${result}"
}

case "${1:-}" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  status)
    status
    ;;
  password)
    cat "${PASSWORD_FILE}"
    ;;
  exec)
    # Container command wrapper: bring the desktop up, then become the real
    # command. A desktop that fails to start is reported and skipped -- the
    # development container must stay usable without it.
    shift
    if (( $# == 0 )); then
      log "exec requires a command"
      exit 64
    fi
    start || log "desktop did not start; continuing without it"
    exec "$@"
    ;;
  *)
    log "usage: core-desktop start|stop|status|password|exec <command...>"
    exit 64
    ;;
esac
