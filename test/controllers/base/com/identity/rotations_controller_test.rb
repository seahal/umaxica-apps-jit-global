# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::Identity::RotationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_corporate)
    @visitor = create_verified_visitor_with_email(email_address: "com-rotation-#{SecureRandom.hex(4)}@example.com")
    @secret = create_active_secret_credential(@visitor)
  end

  test "the owner is handed to the secret credential edit page" do
    post base_com_identity_secret_rotation_url(@secret.public_id, ri: "jp", host: @host),
         headers: as_visitor_headers(@visitor, host: @host)

    assert_response :see_other
    assert_redirected_to edit_base_com_identity_secret_path(@secret.public_id, ri: "jp")
  end

  test "a credential owned by another visitor is not found" do
    other = create_verified_visitor_with_email(email_address: "com-rotation-other-#{SecureRandom.hex(4)}@example.com")
    other_secret = create_active_secret_credential(other)

    post base_com_identity_secret_rotation_url(other_secret.public_id, ri: "jp", host: @host),
         headers: as_visitor_headers(@visitor, host: @host)

    assert_response :not_found
  end

  test "an unauthenticated request is not handed to the edit page" do
    post base_com_identity_secret_rotation_url(@secret.public_id, ri: "jp", host: @host)

    assert_not_equal edit_base_com_identity_secret_path(@secret.public_id, ri: "jp"),
                     URI(response.location.to_s).request_uri
    assert_not_predicate response, :successful?
  end

  private

  def create_active_secret_credential(visitor)
    VisitorSecretCredential.create!(
      visitor: visitor,
      name: "Rotation test secret credential",
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
