# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::Identity::RemovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_corporate)
    @visitor = create_verified_visitor_with_email(email_address: "com-removal-#{SecureRandom.hex(4)}@example.com")
    @secret = create_active_secret_credential(@visitor)
  end

  test "removes the secret credential when another AAL1 method still remains" do
    post base_com_identity_secret_removal_url(@secret.public_id, ri: "jp", host: @host),
         headers: step_up_visitor_headers(@visitor, host: @host)

    assert_response :see_other
    assert_redirected_to base_com_identity_secrets_path(ri: "jp")

    @secret.reload

    assert_equal VisitorSecretCredential.status_id_for(:deleted), @secret.visitor_secret_credential_status_id
    assert_predicate @secret.discarded_at, :present?
  end

  test "refuses to remove the credential that carries the only remaining AAL1 method" do
    # A verified telephone keeps the visitor contactable (so the credential may exist at all) without
    # contributing an AAL1 method, which leaves the secret credential as the only way to sign in.
    lone = create_visitor_with_verified_telephone
    lone_secret = create_active_secret_credential(lone)

    post base_com_identity_secret_removal_url(lone_secret.public_id, ri: "jp", host: @host),
         headers: step_up_visitor_headers(lone, host: @host)

    assert_response :see_other
    assert_redirected_to base_com_identity_secrets_path(ri: "jp")

    lone_secret.reload

    assert_equal VisitorSecretCredentialStatus::ACTIVE, lone_secret.visitor_secret_credential_status_id
  end

  test "a credential owned by another visitor is not found" do
    other = create_verified_visitor_with_email(email_address: "com-removal-other-#{SecureRandom.hex(4)}@example.com")
    other_secret = create_active_secret_credential(other)

    post base_com_identity_secret_removal_url(other_secret.public_id, ri: "jp", host: @host),
         headers: step_up_visitor_headers(@visitor, host: @host)

    assert_response :not_found
    assert_equal VisitorSecretCredentialStatus::ACTIVE, other_secret.reload.visitor_secret_credential_status_id
  end

  test "removal without fresh step-up is refused and keeps the credential" do
    post base_com_identity_secret_removal_url(@secret.public_id, ri: "jp", host: @host),
         headers: as_visitor_headers(@visitor, host: @host)

    assert_response :unauthorized
    assert_equal VisitorSecretCredentialStatus::ACTIVE, @secret.reload.visitor_secret_credential_status_id
  end

  private

  def step_up_visitor_headers(actor, host:)
    headers = as_visitor_headers(actor, host: host)
    VisitorToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID")).update_columns(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_secret_credential",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"),
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:com",
    )
    headers
  end

  def create_active_secret_credential(visitor)
    VisitorSecretCredential.create!(
      visitor: visitor,
      name: "Removal test secret credential",
      password: "a" * 32,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
      visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
    )
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id,
      address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
    visitor.refresh_mfa_status! if visitor.respond_to?(:refresh_mfa_status!)
    visitor.reload
  end

  def create_visitor_with_verified_telephone
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    visitor.visitor_telephones.create!(
      number: "+8190#{format("%08d", SecureRandom.random_number(100_000_000))}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    visitor.reload
    visitor.refresh_mfa_status! if visitor.respond_to?(:refresh_mfa_status!)
    visitor.reload
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    [
      VisitorSecretCredentialStatus::ACTIVE,
      VisitorSecretCredentialStatus::DELETED,
      VisitorSecretCredentialStatus::NOTHING,
    ].each { |id| VisitorSecretCredentialStatus.find_or_create_by!(id: id) }
    VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
  end
end
