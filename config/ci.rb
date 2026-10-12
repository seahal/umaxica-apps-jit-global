# typed: false
# frozen_string_literal: true

# Run using bin/ci

CI.run do
  step "Structure: Repository knowledge", "scripts/check-repository-knowledge"

  step "Setup: create test databases",
       "env RAILS_ENV=test bin/rails db:create"
  step "Setup: test database",
       "POSTGRESQL_TEST_PREPARE_DATABASES=" \
       "test_primary_db,test_publishing_db,test_app_zenith_db,test_com_zenith_db," \
       "test_org_zenith_db,test_app_setting_db,test_com_setting_db,test_org_setting_db," \
       "test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_app_signal_db," \
       "test_com_signal_db,test_org_signal_db,test_avatar_db,test_chronicle_db," \
       "test_occurrence_db,test_queue_db,test_search_db,test_storage_db " \
       "env RAILS_ENV=test bin/rails db:test:prepare"

  step "Style: JavaScript", "bun run check"
  step "Style: Ruby", "bin/rubocop"
  step "Style: ERB", "bundle exec erb_lint --lint-all"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: JavaScript audit", "bun audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Report: Ruby outdated dependencies", "bundle outdated || true"
  step "Report: JavaScript outdated dependencies", "bun outdated || true"

  step "Smoke: Rails server boot", <<~SH
    set -euo pipefail

    TMPDIR="$(mktemp -d -t rails-server-smoke.XXXXXX)"
    PIDFILE="$TMPDIR/server.pid"
    LOGFILE="$TMPDIR/server.log"

    cleanup() {
      if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
      fi

      rm -rf "$TMPDIR"
    }

    trap cleanup EXIT INT TERM

    SERVER_RUN_ID="ci-server-${BASHPID:-$$}-$(date -u +%Y%m%d%H%M%S)"

    env RAILS_ENV=test \
      VALKEY_NAMESPACE_RUN_ID="$SERVER_RUN_ID" \
      VALKEY_NAMESPACE_WORKER_ID=server \
      bin/rails server \
      --environment test \
      --binding 127.0.0.1 \
      --port 0 \
      --pid "$PIDFILE" \
      >"$LOGFILE" 2>&1 &

    SERVER_PID="$!"

    for _ in $(seq 1 30); do
      if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        cat "$LOGFILE"
        echo "rails server exited before becoming ready" >&2
        exit 1
      fi

      if grep -Eq "Listening on|Use Ctrl-C to stop" "$LOGFILE"; then
        exit 0
      fi

      sleep 1
    done

    cat "$LOGFILE"
    echo "rails server did not become ready" >&2
    exit 1
  SH

  step "Tests: JavaScript", "bun run test:coverage"

  if ENV["COVERAGE"] == "true"
    step "Tests: Rails with coverage", "env COVERAGE=true bin/rails test test/"
  else
    step "Tests: Rails", "bin/rails test"
  end

  step "Security: Authentication invariant guards", <<~SH
    bin/rails test \
      test/security/invariants/lifecycle_direct_state_write_invariant_test.rb \
      test/security/invariants/csrf_verification_strategy_invariant_test.rb \
      test/unit/security/standard_csrf_invariant_test.rb \
      test/unit/security/identity_authority_inversion_guard_test.rb \
      test/unit/security/webauthn_invariants_test.rb
  SH

  # Enable this after db/seeds.rb is intentionally valid as a CI contract.
  # step "Database: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
end
