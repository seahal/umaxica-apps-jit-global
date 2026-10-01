# typed: false
# frozen_string_literal: true

require "test_helper"

class CredentialSecurityTransitionTest < ActiveSupport::TestCase
  test "revokes other client sessions and all step-up grants while retaining current session" do
    actor = clients(:one)
    AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
    current_token = ClientToken.create!(
      user: actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      last_step_up_at: 1.minute.ago,
      last_step_up_scope: "settings_mfa",
      last_step_up_aal: "aal2",
      last_step_up_method: "totp",
      last_step_up_purpose: "step_up",
      last_step_up_audience: "app",
      last_step_up_session_public_id: "current_session",
    )
    other_token = ClientToken.create!(
      user: actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      last_step_up_at: 1.minute.ago,
      last_step_up_scope: "settings_mfa",
      last_step_up_aal: "aal2",
      last_step_up_method: "totp",
      last_step_up_purpose: "step_up",
      last_step_up_audience: "app",
      last_step_up_session_public_id: "other_session",
    )
    ClientStepUpSession.create!(
      user_token: other_token,
      scope: "settings_mfa",
      return_to: "/identity/mfa/challenge",
      status: "VERIFIED",
      method: "totp",
      verified_at: 1.minute.ago,
      discard_at: 10.minutes.from_now,
    )
    ClientStepUpSession.create!(
      user_token: current_token,
      scope: "settings_mfa",
      return_to: "/identity/mfa/challenge",
      status: "VERIFIED",
      method: "totp",
      verified_at: 1.minute.ago,
      discard_at: 10.minutes.from_now,
    )
    step_up_selects = []
    subscriber =
      lambda do |_name, _start, _finish, _id, payload|
        sql = payload[:sql].to_s
        step_up_selects << sql if sql.match?(/\ASELECT .*FROM "client_step_up_sessions"/)
      end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      assert_difference -> {
        ClientChronicle.where(event_id: ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION).count
      }, 1 do
        result = CredentialSecurityTransition.call(
          actor: actor,
          current_session: current_token,
          reason: :mfa_disabled,
          affected_surface: "app",
        )

        assert_equal 1, result.revoked_session_count
        assert_equal 2, result.revoked_step_up_count
      end
    end
    assert_equal 1, step_up_selects.length

    assert_predicate current_token.reload, :currently_usable?
    assert_predicate other_token.reload, :revoked?
    assert_nil current_token.last_step_up_at
    assert_nil other_token.last_step_up_at
    assert_operator current_token.step_up_session.reload.discard_at, :<=, Time.current
    assert_operator other_token.step_up_session.reload.discard_at, :<=, Time.current

    audit = ClientChronicle.where(event_id: ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION).order(:created_at).last

    assert_equal "credential_security_transition.mfa_disabled", audit.context.fetch("action")
    assert_equal "mfa_disabled", audit.context.fetch("reason")
    assert_equal "app", audit.context.fetch("surface")
    assert_equal 1, audit.context.fetch("revoked_session_count")
    assert_equal 2, audit.context.fetch("revoked_step_up_count")
    assert_not_includes audit.context.to_s, current_token.public_id
    assert_not_includes audit.context.to_s, other_token.public_id
  end

  test "rejects unknown transition reason fail closed" do
    error =
      assert_raises(ArgumentError) do
        CredentialSecurityTransition.call(
          actor: clients(:one),
          current_session: nil,
          reason: :unknown,
          affected_surface: "app",
        )
      end

    assert_match(/unsupported credential transition reason/, error.message)
  end
end
