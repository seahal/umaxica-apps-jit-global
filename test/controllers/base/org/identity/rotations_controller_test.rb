# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Identity::RotationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_staff)
    ensure_operator_reference_records!
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
    @secret = create_active_secret_credential(@operator)
  end

  test "the owner is handed to the secret credential edit page" do
    post base_org_identity_secret_rotation_url(@secret.public_id, ri: "jp", host: @host),
         headers: as_staff_headers(@operator, host: @host)

    assert_response :see_other
    assert_redirected_to edit_base_org_identity_secret_path(@secret.public_id, ri: "jp")
  end

  test "a credential owned by another operator is not found" do
    other = Operator.create!(status_id: OperatorStatus::ACTIVE)
    other_secret = create_active_secret_credential(other)

    post base_org_identity_secret_rotation_url(other_secret.public_id, ri: "jp", host: @host),
         headers: as_staff_headers(@operator, host: @host)

    assert_response :not_found
  end

  test "an unauthenticated request is not handed to the edit page" do
    post base_org_identity_secret_rotation_url(@secret.public_id, ri: "jp", host: @host)

    assert_not_predicate response, :successful?
    assert_not_equal edit_base_org_identity_secret_path(@secret.public_id, ri: "jp"),
                     URI(response.location.to_s).request_uri
  end

  private

  def create_active_secret_credential(operator)
    OperatorSecretCredential.create!(
      staff: operator,
      name: "Removal test secret credential #{SecureRandom.hex(4)}",
      password_digest: "digest",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
  end

  def ensure_operator_reference_records!
    OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE)
    [
      OperatorSecretCredentialStatus::ACTIVE,
      OperatorSecretCredentialStatus::DELETED,
      OperatorSecretCredentialStatus::REVOKED,
    ].each { |id| OperatorSecretCredentialStatus.find_or_create_by!(id: id) }
    OperatorSecretCredentialKind.find_or_create_by!(id: OperatorSecretCredentialKind::LOGIN)
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end
end
