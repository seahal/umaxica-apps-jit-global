# syntax=docker/dockerfile:1
# check=error=true
# ============================================================================
# Shared build arguments
# ============================================================================
ARG RUBY_VERSION=4.0.6
ARG DOCKER_UID=1000
ARG DOCKER_GID=1000
ARG DOCKER_USER=global
ARG DOCKER_GROUP=umaxica
ARG GITHUB_ACTIONS=""
# Deployment identifier consumed by Rails.application.revision. `.git` is
# excluded from the build context, so the Rails git fallback cannot resolve
# anything inside the image; the commit SHA has to be passed in at build time
# (`--build-arg REVISION="$(git rev-parse HEAD)"`). Empty means the revision
# endpoints report null rather than a wrong value.
ARG REVISION=""
# Node.js Active LTS (v24 "Krypton"; maintenance starts 2026-10-20). Pinned to an
# exact patch so Global and Edge cannot drift to different Node builds.
ARG NODE_VERSION=24.20.0
# Bun is pinned for reproducible builds across local containers and CI.
ARG BUN_VERSION=1.4.0

# ============================================================================
# Node.js toolchain (binaries copied into the development and asset images)
# ============================================================================
FROM node:${NODE_VERSION}-trixie-slim AS node-toolchain

# Bun toolchain (standalone binary copied into development and asset images)
# ============================================================================
FROM docker.io/oven/bun:${BUN_VERSION} AS bun-toolchain
# ============================================================================
# Production base — runtime-only dependencies
# ============================================================================
FROM docker.io/library/ruby:${RUBY_VERSION}-slim-trixie AS production-base
SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]
ARG DOCKER_UID
ARG DOCKER_GID
ARG DOCKER_USER
ARG DOCKER_GROUP
ENV HOME=/home/${DOCKER_USER}
ENV APP_HOME=${HOME}/main
ENV LANG=C.UTF-8 \
    IS_SANDBOX=1 \
    RAILS_ENV=production \
    RACK_ENV=production \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_APP_CONFIG=/usr/local/bundle/.bundle \
    BUNDLE_FROZEN=1 \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# Update RubyGems before installing the latest Bundler
RUN gem update --system \
    && gem install bundler

WORKDIR ${APP_HOME}

RUN if ! getent group "${DOCKER_GROUP}" >/dev/null; then \
    groupadd --gid "${DOCKER_GID}" "${DOCKER_GROUP}"; \
    fi \
    && if ! id -u "${DOCKER_USER}" >/dev/null 2>&1; then \
    useradd --uid "${DOCKER_UID}" --gid "${DOCKER_GROUP}" --home "${HOME}" --shell /usr/sbin/nologin "${DOCKER_USER}"; \
    fi \
    && mkdir -p "${APP_HOME}" "${HOME}" \
    && chown -R "${DOCKER_UID}:${DOCKER_GID}" "${HOME}"

# apt lists / archives live in BuildKit cache mounts (not in the image layer),
# so rebuilds reuse downloads while the final image stays clean.
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    libjemalloc2 \
    libpq5 \
    libyaml-0-2 \
    tzdata \
    && rm -f /usr/local/bin/gosu /usr/local/bin/gosu-*

# ============================================================================
# Production assets — Vite/Inertia client bundles
#
# Runs on the pinned Node image rather than inside the Ruby build stage: vite-plugin-ruby reads
# config/vite.json directly, so compiling the bundles needs Node, Bun, and no Ruby.
#
# NODE_ENV is set to production here and nowhere else in the build. @vitejs/plugin-react keys the
# JSX runtime off it, so a build inheriting the development compose environment ships the React
# development runtime (jsx-dev-runtime) and its warning machinery to end users.
# ============================================================================
FROM node:${NODE_VERSION}-trixie-slim AS production-assets
ENV NODE_ENV=production \
    VITE_RUBY_MODE=production \
    CI=true \
    LEFTHOOK=0

WORKDIR /assets

# Copy the pinned Bun binary from the official release image; package resolution below is lockfile-only.
COPY --from=bun-toolchain /usr/local/bin/bun /usr/local/bin/bun

# Dependencies resolve from the Bun lockfile alone, so this layer is reused until a dependency
# changes. Dev dependencies remain installed because Vite and its plugins are required to build assets.
COPY package.json bun.lock ./
RUN --mount=type=cache,target=/root/.bun/install/cache \
    bun install --frozen-lockfile

COPY config/vite.json ./config/vite.json
COPY vite.config.ts tsconfig.json tsconfig.app.json tsconfig.node.json ./
COPY src ./src

# The manifest check catches a build that produced no entrypoints; the runtime resolves every
# `vite_typescript_tag` through it. The React-runtime check is the tripwire for a lost NODE_ENV:
# the build still succeeds in that case, it just ships the development bundle.
RUN bunx vite build --mode production \
    && test -f public/vite/.vite/manifest.json \
    && if grep -rql "jsx-dev-runtime\|jsxDEV" public/vite/assets; then \
    echo "Production bundle contains the React development JSX runtime" >&2; \
    exit 1; \
    fi

# ============================================================================
# Production build — gems + asset/bootsnap precompile
# ============================================================================
FROM production-base AS production-build
ARG DOCKER_UID
ARG DOCKER_GID

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libpq-dev \
    libyaml-dev \
    pkg-config \
    unzip

COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/tmp/bundle-cache,uid=${DOCKER_UID},gid=${DOCKER_GID} \
    bundle config set --local cache_path /tmp/bundle-cache \
    && bundle install --jobs "${BUNDLE_JOBS}" --retry "${BUNDLE_RETRY}" \
    && bundle exec bootsnap precompile --gemfile \
    && bundle clean --force \
    && rm -rf /usr/local/bundle/cache

COPY . .

# The Vite manifest is what `vite_javascript_tag` resolves entrypoints through, so the runtime
# image cannot render a single layout without it. `public/vite` is excluded from the build context
# (.dockerignore/.containerignore) precisely so this copy is the only source of it.
COPY --from=production-assets /assets/public/vite ./public/vite

RUN install -d tmp/pids log \
    && rm -rf tmp/cache \
    && find log -type f -exec truncate -s 0 {} + \
    && rm -f tmp/pids/server.pid \
    && bundle exec bootsnap precompile app/ lib/

# ============================================================================
# Production runtime
# ============================================================================
FROM production-base AS production
ARG DOCKER_UID
ARG DOCKER_GID
ARG DOCKER_USER
ARG REVISION
ENV REVISION=${REVISION}
ENV PORT=8080 \
    RUBY_YJIT_ENABLE=1 \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=true \
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2 \
    PATH=/usr/local/bundle/bin:${PATH}

COPY --from=production-build --chown=${DOCKER_UID}:${DOCKER_GID} /usr/local/bundle /usr/local/bundle
COPY --from=production-build --chown=${DOCKER_UID}:${DOCKER_GID} ${APP_HOME} ${APP_HOME}

# Single hardening layer: lock out root + drop privilege-escalation paths,
# create owner-only writable runtime dirs, then make app + bundle read/exec only.
# Order is preserved: writable dirs are created before the chmod 500 sweep,
# which deliberately excludes tmp/log/storage.
RUN usermod -s /usr/sbin/nologin root \
    && usermod -L root \
    && rm -f /usr/bin/sudo /usr/bin/su /usr/sbin/sudo /usr/sbin/su \
    && rm -f /usr/bin/chsh /usr/bin/chfn /usr/bin/newgrp /usr/bin/passwd /usr/bin/gpasswd \
    && find / -xdev -perm /4000 -exec chmod u-s {} + 2>/dev/null || true \
    && find / -xdev -perm /2000 -exec chmod g-s {} + 2>/dev/null || true \
    && install -d -m 700 -o "${DOCKER_UID}" -g "${DOCKER_GID}" \
    tmp tmp/pids tmp/cache tmp/sockets \
    log \
    storage \
    && find "${APP_HOME}" -mindepth 1 \
    ! -type l \
    ! -path "${APP_HOME}/tmp/*" \
    ! -path "${APP_HOME}/log/*" \
    ! -path "${APP_HOME}/storage/*" \
    -exec chmod 500 {} + \
    && find /usr/local/bundle ! -type l -exec chmod 500 {} +

USER ${DOCKER_USER}

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ruby -rsocket -e "TCPSocket.new('127.0.0.1', Integer(ENV.fetch('PORT', '8080'))).close"

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb", "--port", "8080"]

# ============================================================================
# Development base — system packages for the docker compose workflow
# ============================================================================
FROM docker.io/library/ruby:${RUBY_VERSION}-trixie AS development-base
SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]
ENV TZ=UTC \
    LANG=C.UTF-8 \
    IS_SANDBOX=1 \
    LC_ALL=C.UTF-8 \
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# Update RubyGems before installing the latest Bundler
RUN gem update --system \
    && gem install bundler

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update -qq \
    && apt-get install --no-install-recommends -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    graphviz \
    libjemalloc2 \
    libpq-dev \
    libvips \
    libxml2-dev \
    libyaml-dev \
    postgresql-client \
    tzdata \
    unzip \
    zlib1g-dev \
    && rm -rf /tmp/* /var/tmp/*

# ============================================================================
# Development image (used by docker compose)
# ============================================================================
FROM development-base AS development
SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]
ARG DOCKER_UID
ARG DOCKER_GID
ARG DOCKER_USER
ARG DOCKER_GROUP
ARG GITHUB_ACTIONS
ARG BUN_VERSION
# `exec`-created sessions inherit no login shell, so SHELL is unset and every
# tool that shells out (Dev Containers CLI, git, editors, agents) falls back to
# /bin/sh -- dash here. The account's shell is already bash; this makes the
# environment agree with it.
ENV HOME=/home/${DOCKER_USER} \
    SHELL=/bin/bash \
    CORE_WORKLOAD_USER=${DOCKER_USER} \
    CORE_WORKLOAD_GROUP=${DOCKER_GROUP}
WORKDIR ${HOME}/workspace

COPY --from=node-toolchain /usr/local/bin/node /usr/local/bin/node
COPY --from=node-toolchain /usr/local/lib/node_modules /usr/local/lib/node_modules
# Node remains available for runtime compatibility; Bun is the sole JavaScript package manager.
COPY --from=bun-toolchain /usr/local/bin/bun /usr/local/bin/bun

# The lib* packages below are Chromium's shared-library closure, for the Vitest
# `component` project, which runs against a real browser rather than jsdom (see
# vitest.config.ts). Playwright downloads the browser binary itself but never its
# system dependencies, so without these `chrome-headless-shell` exits 127 on
# libatk-1.0.so.0 and the whole project fails to start before any test runs.
# Trixie carries the 64-bit-time_t (`t64`) names.
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && curl -1sLf "https://dl.cloudsmith.io/public/evilmartians/lefthook/setup.deb.sh" | bash \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg \
      -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && echo 'deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian trixie main' \
      > /etc/apt/sources.list.d/tailscale.list \
    && apt-get update -qq \
    && apt-get install --no-install-recommends -y \
    bat \
    bubblewrap \
    entr \
    fd-find \
    fontconfig \
    fzf \
    git-secrets \
    gitleaks \
    htop \
    iproute2 \
    jq \
    lefthook \
    libasound2t64 \
    libatk-bridge2.0-0t64 \
    libatk1.0-0t64 \
    libatspi2.0-0t64 \
    libcairo2 \
    libcups2t64 \
    libdrm2 \
    libgbm1 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    lsb-release \
    ncdu \
    netcat-openbsd \
    openssh-client \
    openssh-server \
    openssl \
    ripgrep \
    silversearcher-ag \
    socat \
    tailscale=1.102.3 \
    tig \
    tree \
    util-linux \
    watch \
    wget \
    yq \
    zip \
    && rm -rf /tmp/* /var/tmp/* "/home/${DOCKER_USER}/"

# Dev Container features run `chown $_REMOTE_USER:$_REMOTE_USER`, which assumes a
# group named after the user. The primary group here is ${DOCKER_GROUP}, so a
# supplementary group named ${DOCKER_USER} is created to keep those features
# installable without changing file ownership semantics for the workload.
RUN if [ -z "${GITHUB_ACTIONS}" ]; then \
    groupadd -g "${DOCKER_GID}" "${DOCKER_GROUP}"; \
    useradd -l -u "${DOCKER_UID}" -g "${DOCKER_GROUP}" -m -s /bin/bash "${DOCKER_USER}"; \
    usermod -L "${DOCKER_USER}"; \
    groupadd "${DOCKER_USER}"; \
    usermod -aG "${DOCKER_USER}" "${DOCKER_USER}"; \
    else \
    mkdir -p "${HOME}"; \
    fi

# Bun is copied from the pinned toolchain stage above; no second package manager is installed.

# Final ownership fix for the home directory, workspace, and bundler's own
# GEM_HOME (gem install bundler above runs as root; production handles this
# via COPY --chown, development has no equivalent step).
#
# The XDG directories are load-bearing, not cosmetic. Compose mounts named volumes
# at .cache and .local/share, so materialize their parents before the ownership
# fix below. The remote-sshd paths serve the opt-in access overlay and retain the
# same ownership semantics across the Global, Edge, and portal images.
RUN mkdir -p "${HOME}/workspace" \
    "${HOME}/.cache" \
    "${HOME}/.bun/install/cache" \
    "${HOME}/.config" \
    "${HOME}/.local/bin" \
    "${HOME}/.local/share" \
    "${HOME}/.local/state" \
    "${HOME}/.local/state/remote-sshd" \
    "${HOME}/.local/state/tailscale" \
    "${HOME}/.config/umaxica" \
    && chown -R "${DOCKER_UID}:${DOCKER_GID}" "${HOME}" /usr/local/bundle \
    && chmod 0700 "${HOME}/.local/state/remote-sshd" \
    && chmod 0700 "${HOME}/.local/state/tailscale" \
    && chmod 0755 "${HOME}/.config/umaxica"

COPY --chown=0:0 podman/core/entrypoint.sh /usr/local/bin/core-entrypoint
COPY --chown=0:0 podman/core/dev-supervisor.sh /usr/local/bin/core-dev-supervisor
# Root-owned and read-only: `global` owns the workspace bind, so leaving either of
# these there would let anything with a development shell rewrite what the next
# container start executes -- including which keys it accepts.
#
# Both are inert unless `compose.remote-access.yaml` replaces `core`'s command.
# The names are the shared ones: umaxica-apps-edge and portal bake the same two
# paths from the same two source files.
COPY --chown=0:0 .devcontainer/remote-sshd_config /etc/ssh/remote-sshd_config
COPY --chown=0:0 .devcontainer/remote-sshd-entrypoint.sh /usr/local/bin/remote-sshd-entrypoint

# Shadows /usr/bin/tailscale on PATH: the bare CLI expects a root tailscaled
# this container can never run. The wrapper targets — and on first use starts —
# the user-space daemon, so `tailscale up` works in any shell. See the script.
COPY --chown=0:0 .devcontainer/tailscale-wrapper.sh /usr/local/bin/tailscale

RUN chmod 0555 \
    /usr/local/bin/core-entrypoint \
    /usr/local/bin/core-dev-supervisor \
    /usr/local/bin/remote-sshd-entrypoint \
    /usr/local/bin/tailscale \
    && chmod 0444 /etc/ssh/remote-sshd_config

USER ${DOCKER_USER}

# ============================================================================
# Persistent coding workspace — development plus nested rootless Podman
# ============================================================================
FROM development AS workspace
SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]
ARG DOCKER_UID
ARG DOCKER_GID
ARG DOCKER_USER

USER root

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update -qq \
    && apt-get install --no-install-recommends -y \
    fuse-overlayfs \
    passt \
    podman \
    slirp4netns \
    uidmap \
    && rm -rf /tmp/* /var/tmp/*

# The outer rootless user namespace exposes IDs 1..65536. Reserve all IDs
# except the baked development UID/GID for the inner rootless Podman user.
RUN configure_subids() { \
      local name=$1 value=$2 file=$3; \
      sed -i "/^${name}:/d" "${file}"; \
      if (( value >= 1 && value <= 65536 )); then \
        if (( value > 1 )); then \
          printf '%s:1:%s\n' "${name}" "$((value - 1))" >> "${file}"; \
        fi; \
        if (( value < 65536 )); then \
          printf '%s:%s:%s\n' "${name}" "$((value + 1))" "$((65536 - value))" >> "${file}"; \
        fi; \
      else \
        printf '%s:1:65536\n' "${name}" >> "${file}"; \
      fi; \
    }; \
    configure_subids "${DOCKER_USER}" "${DOCKER_UID}" /etc/subuid; \
    configure_subids "${DOCKER_USER}" "${DOCKER_GID}" /etc/subgid; \
    install -d -m 0700 -o "${DOCKER_UID}" -g "${DOCKER_GID}" \
      "/run/user/${DOCKER_UID}" \
      "/home/${DOCKER_USER}/.local/share/containers"

ENV XDG_RUNTIME_DIR=/run/user/${DOCKER_UID}

USER ${DOCKER_USER}

# Omitting --target must always produce the deployable runtime image.
FROM production AS final
