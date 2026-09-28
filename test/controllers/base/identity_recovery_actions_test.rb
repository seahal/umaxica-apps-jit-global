# typed: false
# frozen_string_literal: true

require "test_helper"

# The two write endpoints a locked-out principal reaches once the recovery
# ceremony cookie has been issued: submitting an appeal against an in-force
# enforcement case, and completing a verification-released security lock.
class BaseIdentityRecoveryActionsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "app appeal submission records the appeal and returns to the recovery page" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    client = Client.create!(
      status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING, mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    email = ClientEmail.create!(
      user: client, address: "recovery-appeal-client@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: "recovery-test-operator",
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: enforcement_case,
      actor_operator_public_id: enforcement_case.applied_by_operator_public_id,
    )
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, adapter) do
      post base_app_identity_recovery_session_url(ri: "jp", host: host),
           params: { recovery_reentry: { address: email.address } }
    end
    otp = email.reload.get_otp
    post base_app_identity_recovery_session_url(ri: "jp", host: host),
         params: { pass_code: ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s }

    assert_difference("AppEnforcementAppeal.count", 1) do
      post base_app_identity_recovery_appeals_url(ri: "jp", host: host),
           params: {
             appeal: {
               enforcement_case_id: enforcement_case.public_id,
               reason_code: "incorrect_decision",
               statement: "appeal statement for the enforcement case",
             },
           }
    end

    assert_response :see_other
    assert_redirected_to base_app_identity_recovery_path(ri: "jp")
  end

  test "app appeal submission re-renders the recovery page when the appeal is rejected" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    client = Client.create!(
      status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING, mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    email = ClientEmail.create!(
      user: client, address: "recovery-appeal-invalid@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: "recovery-test-operator",
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: enforcement_case,
      actor_operator_public_id: enforcement_case.applied_by_operator_public_id,
    )
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, adapter) do
      post base_app_identity_recovery_session_url(ri: "jp", host: host),
           params: { recovery_reentry: { address: email.address } }
    end
    otp = email.reload.get_otp
    post base_app_identity_recovery_session_url(ri: "jp", host: host),
         params: { pass_code: ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s }

    assert_no_difference("AppEnforcementAppeal.count") do
      post base_app_identity_recovery_appeals_url(ri: "jp", host: host),
           params: {
             appeal: {
               enforcement_case_id: enforcement_case.public_id,
               reason_code: "not_a_supported_reason",
               statement: "appeal statement for the enforcement case",
             },
           }
    end

    assert_response :unprocessable_content
  end

  test "app recovery completion ends the security lock and returns to sign-in" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    client = Client.create!(
      status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING, mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
    email = ClientEmail.create!(
      user: client, address: "recovery-completion-client@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    enforcement_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: client.public_id, applied_by_operator_public_id: "recovery-test-operator",
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: enforcement_case,
      actor_operator_public_id: enforcement_case.applied_by_operator_public_id,
    )
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, adapter) do
      post base_app_identity_recovery_session_url(ri: "jp", host: host),
           params: { recovery_reentry: { address: email.address } }
    end
    otp = email.reload.get_otp
    post base_app_identity_recovery_session_url(ri: "jp", host: host),
         params: { pass_code: ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s }

    post base_app_identity_recovery_completion_url(ri: "jp", host: host),
         params: { enforcement_case_id: enforcement_case.public_id }

    assert_response :see_other
    assert_not AppEnforcementCase.in_force.exists?(id: enforcement_case.id)
  end

  test "com appeal submission records the appeal and returns to the recovery page" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    email = VisitorEmail.create!(
      visitor: visitor, address: "recovery-appeal-visitor@example.test", confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    enforcement_case = ComEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: visitor.public_id, applied_by_operator_public_id: "recovery-test-operator",
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: enforcement_case,
      actor_operator_public_id: enforcement_case.applied_by_operator_public_id,
    )
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, adapter) do
      post base_com_identity_recovery_session_url(ri: "jp", host: host),
           params: { recovery_reentry: { address: email.address } }
    end
    otp = email.reload.get_otp
    post base_com_identity_recovery_session_url(ri: "jp", host: host),
         params: { pass_code: ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s }

    assert_difference("ComEnforcementAppeal.count", 1) do
      post base_com_identity_recovery_appeals_url(ri: "jp", host: host),
           params: {
             appeal: {
               enforcement_case_id: enforcement_case.public_id,
               reason_code: "new_information",
               statement: "appeal statement for the corporate enforcement case",
             },
           }
    end

    assert_response :see_other
  end

  test "com recovery completion ends the security lock and returns to sign-in" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    email = VisitorEmail.create!(
      visitor: visitor, address: "recovery-completion-visitor@example.test", confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    enforcement_case = ComEnforcementCase.create!(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: visitor.public_id, applied_by_operator_public_id: "recovery-test-operator",
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: enforcement_case,
      actor_operator_public_id: enforcement_case.applied_by_operator_public_id,
    )
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, adapter) do
      post base_com_identity_recovery_session_url(ri: "jp", host: host),
           params: { recovery_reentry: { address: email.address } }
    end
    otp = email.reload.get_otp
    post base_com_identity_recovery_session_url(ri: "jp", host: host),
         params: { pass_code: ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s }

    post base_com_identity_recovery_completion_url(ri: "jp", host: host),
         params: { enforcement_case_id: enforcement_case.public_id }

    assert_response :see_other
    assert_not ComEnforcementCase.in_force.exists?(id: enforcement_case.id)
  end

  test "app appeal submission without a recovery ceremony is sent back to the entry point" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    post base_app_identity_recovery_appeals_url(ri: "jp", host: host),
         params: { appeal: { enforcement_case_id: "x", reason_code: "other", statement: "y" } }

    assert_response :see_other
    assert_match %r{/identity/recovery/session/new}, response.location
  end
end
