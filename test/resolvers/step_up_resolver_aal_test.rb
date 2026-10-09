# typed: false
# frozen_string_literal: true

require "test_helper"

class StepUpResolverAalTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "legacy AAL demands are refused rather than translated into authorization" do
    %i(aal1 aal2 aal3).each do |level|
      error =
        assert_raises(StepUpRequirement::Invalid) do
          StepUpResolver.call(token: nil, scope: "settings_email", required_aal: level)
        end

      assert_equal "legacy AAL requirements are unsupported", error.message
    end
  end

  test "an AAL label cannot satisfy a phishing resistance requirement without its verified property" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_email", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:resolver", last_step_up_credential_ref: SecureRandom.uuid,
      last_step_up_phishing_resistant: false, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    %w(aal1 aal2 aal3).each do |level|
      token.update!(last_step_up_aal: level)
      result = StepUpResolver.call(token: token, scope: "settings_email", phishing_resistant_required: true)

      assert result.usable_token
      assert_not result.satisfied
      assert_nil result.required_aal
    end
  end

  test "verified properties satisfy the requirement independently of a missing or lower AAL label" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_email", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:resolver", last_step_up_credential_ref: SecureRandom.uuid,
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    [nil, "aal1"].each do |level|
      token.update!(last_step_up_aal: level)
      result = StepUpResolver.call(token: token, scope: "settings_email", phishing_resistant_required: true)

      assert result.satisfied
      assert_nil result.required_aal
      assert_equal "settings_email", result.scope
    end
  end

  test "an absent evidence property refuses even a labeled session" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_email", last_step_up_method: "passkey",
      last_step_up_aal: "aal2", last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:resolver", last_step_up_credential_ref: SecureRandom.uuid,
      last_step_up_phishing_resistant: true, last_step_up_user_verified: nil,
      last_step_up_full_reauthentication: false,
    )
    result = StepUpResolver.call(token: token, scope: "settings_email")

    assert result.usable_token
    assert_not result.satisfied
    assert_nil result.required_aal
  end
end
