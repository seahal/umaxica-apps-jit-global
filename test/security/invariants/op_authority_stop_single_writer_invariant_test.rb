# frozen_string_literal: true

require "test_helper"

# BX-1 / two.md 5.8 v2 (D-172, D-173): only OpAuthorityStopCommitter revokes an OP root or grant.
# Every other `revoke!` call in app/ and lib/ must name a receiver that is neither, and the grant's
# lock-holding revoke is called from the primitive alone.
class OpAuthorityStopSingleWriterInvariantTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  PRIMITIVE = "app/operations/op_authority_stop_committer.rb"
  # Receivers of `revoke!` that are not OP roots or grants: Device Sessions (`revoke!(reason:)`),
  # ceremony rows, capability grants (`revoke!(by:)`), and SignRiskEnforcer's actor-side event
  # transition. The latter commits the identity epoch before OP stops are applied.
  NON_AUTHORITY_CALLS = [
    %r{\Aapp/models/concerns/token_status_management\.rb:\s*ceremony\.revoke!\(},
    %r{\Aapp/services/credential_security_transition\.rb:\s*ceremony\.revoke!\(},
    %r{\Aapp/controllers/concerns/auth_ceremony_context\.rb:\s*current_auth_ceremony_session&\.revoke!\z},
    %r{\Aapp/controllers/concerns/withdrawal_ceremony_authentication\.rb:\s*ceremony\.revoke!\z},
    %r{\Aapp/operations/op_identity_event_invalidator\.rb:.*device_session_record&\.revoke!\(reason:},
    %r{\Aapp/controllers/concerns/authentication_logout_current_session\.rb:\s*device_session&\.revoke!\(reason:},
    %r{\Aapp/controllers/concerns/authentication_logout_current_session\.rb:\s*SignRiskEnforcer\.revoke!\(actor\)},
    %r{\Aapp/operations/client_secret_revocation_committer\.rb:\s*revoke!\(actor_context,},
    %r{\Aapp/services/sign_risk_enforcer\.rb:\s*revoke!\(resource\)},
    %r{\Aapp/controllers/base/org/api/v0/iam/grants_controller\.rb:\s*grant\.revoke!\(by:},
  ].freeze

  test "only the authority-stop primitive revokes OP roots and grants" do
    violations =
      source_lines.filter_map do |path, line|
        next if line.match?(/\bdef (self\.)?revoke(_under_stop_lock)?!/)
        next unless line.match?(/(\.|\A\s*)revoke(_under_stop_lock)?!/)
        next if path == PRIMITIVE

        located = "#{path}: #{line.strip}"
        next if NON_AUTHORITY_CALLS.any? { |pattern| located.match?(pattern) }

        located
      end

    assert_empty violations, "OP roots and grants are revoked only through OpAuthorityStopCommitter"
  end

  test "the primitive is the only caller of the grant's lock-holding revoke" do
    callers =
      source_lines.select do |_path, line|
        line.include?("revoke_under_stop_lock!") && line.exclude?("def ")
      end

    assert_equal [PRIMITIVE], callers.map(&:first).uniq
  end

  private

  def source_lines
    Rails.root.glob("{app,lib}/**/*.rb").flat_map do |file|
      path = file.relative_path_from(Rails.root).to_s
      file.readlines.map { |line| [path, line] }
    end
  end
end
