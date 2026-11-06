# frozen_string_literal: true

require "test_helper"

class BaseOrgIamOwnerApiTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  self.use_transactional_tests = false

  test "IAM grant and revoke commit through the owner boundary and preserve the API response shape" do
    created_policy = nil
    unless ChronicleRetentionPolicy.exists?(code: "compliance")
      created_policy = ChronicleRetentionPolicy.create!(
        code: "compliance", name: "Compliance", duration_days: 365, permanent: false,
      )
    end
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    subject = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    OperatorCapabilityGrant.bootstrap!(
      operator: actor,
      capabilities: [
        OperatorCapabilityGrant::IAM_CAPABILITY_READ,
        OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
        OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE,
        OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      ],
      ticket_id: "IAM-API-ACTOR",
      expires_at: 7.days.from_now,
    )

    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host!(host)
    https!
    now = OpBaseOrgRecord.database_now
    root = OperatorToken.create!(
      authentication_epoch: actor.authentication_epoch,
      staff: actor,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: now + 1.hour,
      root_login_established_at: now,
      established_authentication_method: "passkey",
    )
    root.rotate_refresh_token!(now:)
    root.device_session_record!
    client = OidcClientRegistry.find!("base-org-ww")
    op_grant = OpOrgGrant.create!(
      authentication_epoch: root.authentication_epoch,
      operator_token: root,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    op_grant.issue_refresh_token!(now:)
    access_token = AuthenticationTokenService.encode(
      actor,
      host: host,
      resource_type: "operator",
      session_public_id: root.public_id,
      base_session_public_id: root.public_id,
      oidc_sid: op_grant.public_id,
      oidc_jti: op_grant.oidc_jti,
      expires_at: now + 4.minutes,
      scopes: %w(openid profile),
      acr: op_grant.oidc_acr,
      amr: ["passkey"],
      auth_time: op_grant.oidc_auth_time,
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(actor, resource_type: "operator"),
      client_id: client.client_id,
      authentication_context: root.strict_authentication_context_value.to_s,
    )
    grant_operation_id = SecureRandom.uuid
    no_proof_operation_id = SecureRandom.uuid
    revoke_operation_id = SecureRandom.uuid
    operation_ids = [grant_operation_id, no_proof_operation_id, revoke_operation_id]
    assertion_jtis = []
    grant_path = "/api/v0/iam/grants"
    grant_url = "https://#{host}#{grant_path}"
    grant_params = {
      operator_public_id: subject.public_id,
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
      reason_code: OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES.first,
      duration_days: "7",
      ticket_id: "IAM-API-7",
      operation_id: grant_operation_id,
    }

    request_without_proof = AuthenticationTokenService.encode(
      actor,
      host: host,
      resource_type: "operator",
      session_public_id: root.public_id,
      base_session_public_id: root.public_id,
      oidc_sid: op_grant.public_id,
      oidc_jti: op_grant.oidc_jti,
      expires_at: now + 4.minutes,
      scopes: %w(openid profile),
      amr: [],
      auth_time: op_grant.oidc_auth_time,
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      subject: OidcSubject.for(actor, resource_type: "operator"),
      client_id: client.client_id,
      authentication_context: root.strict_authentication_context_value.to_s,
    )
    assertion = OidcClientAssertionJwt.issue(client_id: client.client_id, token_url: grant_url)
    assertion_payload, = JWT.decode(assertion, nil, false)
    assertion_jtis << assertion_payload.fetch("jti")
    post(
      grant_path, params: grant_params.merge(operation_id: no_proof_operation_id), headers: {
        "Authorization" => "Bearer #{request_without_proof}",
        "X-Client-Assertion" => assertion,
        "X-Browser-Request-Id" => "iam-no-proof",
        "X-Browser-Ip" => "127.0.0.1",
        "X-Browser-User-Agent" => "test-agent",
      },
    )

    assert_response :forbidden
    assert_equal "step_up_required", response.parsed_body.fetch("error")
    assert_not Chronicle.exists?(event_uuid: no_proof_operation_id)
    assert_not OrgIamOperationOutcome.exists?(operation_id: no_proof_operation_id)

    assertion = OidcClientAssertionJwt.issue(client_id: client.client_id, token_url: grant_url)
    assertion_payload, = JWT.decode(assertion, nil, false)
    assertion_jtis << assertion_payload.fetch("jti")
    post(
      grant_path, params: grant_params, headers: {
        "Authorization" => "Bearer #{access_token}",
        "X-Client-Assertion" => assertion,
        "X-Browser-Request-Id" => "iam-grant",
        "X-Browser-Ip" => "127.0.0.1",
        "X-Browser-User-Agent" => "test-agent",
      },
    )

    assert_response :created
    issued_grant_public_id = response.parsed_body.fetch("grant_public_id")
    issued_grant = OperatorCapabilityGrant.find_by!(public_id: issued_grant_public_id)

    assert_equal subject.id, issued_grant.operator_id
    assert_equal "succeeded", Chronicle.find_by!(event_uuid: grant_operation_id).result
    assert_equal issued_grant_public_id,
                 OrgIamOperationOutcome.find_by!(operation_id: grant_operation_id).result.fetch("grant_public_id")

    assertion = OidcClientAssertionJwt.issue(client_id: client.client_id, token_url: grant_url)
    assertion_payload, = JWT.decode(assertion, nil, false)
    assertion_jtis << assertion_payload.fetch("jti")
    post(
      grant_path, params: grant_params, headers: {
        "Authorization" => "Bearer #{access_token}",
        "X-Client-Assertion" => assertion,
        "X-Browser-Request-Id" => "iam-grant-replay",
        "X-Browser-Ip" => "127.0.0.1",
        "X-Browser-User-Agent" => "test-agent",
      },
    )

    assert_response :created
    assert_equal issued_grant_public_id, response.parsed_body.fetch("grant_public_id")
    assert_equal 1, OperatorCapabilityGrant.where(public_id: issued_grant_public_id).count

    assertion = OidcClientAssertionJwt.issue(client_id: client.client_id, token_url: grant_url)
    assertion_payload, = JWT.decode(assertion, nil, false)
    assertion_jtis << assertion_payload.fetch("jti")
    post(
      grant_path, params: grant_params.merge(duration_days: "30"),
                  headers: {
                    "Authorization" => "Bearer #{access_token}",
                    "X-Client-Assertion" => assertion,
                    "X-Browser-Request-Id" => "iam-grant-conflict",
                    "X-Browser-Ip" => "127.0.0.1",
                    "X-Browser-User-Agent" => "test-agent",
                  },
    )

    assert_response :conflict
    assert_equal 1, OperatorCapabilityGrant.where(
      operator_id: subject.id,
      capability: OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
    ).count
    assert_equal 1, OrgIamOperationOutcome.where(operation_id: grant_operation_id).count

    revoke_path = "/api/v0/iam/grants/#{issued_grant_public_id}/revocation"
    revoke_url = "https://#{host}#{revoke_path}"
    assertion = OidcClientAssertionJwt.issue(client_id: client.client_id, token_url: revoke_url)
    assertion_payload, = JWT.decode(assertion, nil, false)
    assertion_jtis << assertion_payload.fetch("jti")
    post(
      revoke_path, params: {
        reason_code: OperatorCapabilityGrant::REVOKE_REASON_CODES.first,
        operation_id: revoke_operation_id,
      }, headers: {
        "Authorization" => "Bearer #{access_token}",
        "X-Client-Assertion" => assertion,
        "X-Browser-Request-Id" => "iam-revoke",
        "X-Browser-Ip" => "127.0.0.1",
        "X-Browser-User-Agent" => "test-agent",
      },
    )

    assert_response :success
    assert_equal issued_grant_public_id, response.parsed_body.fetch("grant_public_id")
    assert_predicate issued_grant.reload, :revoked?
    revoke_event = Chronicle.find_by!(event_uuid: revoke_operation_id)

    assert_equal "succeeded", revoke_event.result
    assert_equal({ "revoked" => true }, revoke_event.changeset)
  ensure
    Actor.clear
    Chronicle.where(event_uuid: operation_ids).delete_all if defined?(operation_ids) && operation_ids
    OrgIamOperationOutcome.where(operation_id: operation_ids).delete_all if defined?(operation_ids) && operation_ids
    operator_ids = [actor&.id, subject&.id].compact
    OperatorCapabilityGrant.where(operator_id: operator_ids).delete_all if operator_ids.any?
    OperatorCapabilityGrant.where(granted_by_operator_id: operator_ids).delete_all if operator_ids.any?
    SecurityConsumedJti.where(
      purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_client_assertion),
      issuer: "base-org-ww",
      jti_digest: assertion_jtis.map { |jti| SecurityConsumedJti.digest_jti(jti) },
    ).delete_all if defined?(assertion_jtis) && assertion_jtis.any?
    if defined?(root) && root&.persisted?
      device_id = root.reload.device_session_id
      OpOrgGrant.where(operator_token_id: root.id).delete_all
      OperatorDeviceSession.where(id: device_id, staff_id: actor.id).update_all(current_refresh_token_id: nil)
      OperatorToken.where(device_session_id: device_id, staff_id: actor.id).delete_all
      OperatorDeviceSession.where(id: device_id, staff_id: actor.id).delete_all
    end
    ChronicleRetentionPolicy.where(id: created_policy.id).delete_all if defined?(created_policy) && created_policy
    OperatorAuthorityLock.where(operator_id: operator_ids).delete_all if operator_ids.any?
    OperatorAccount.where(staff_id: operator_ids).delete_all if operator_ids.any?
    Operator.where(id: operator_ids).delete_all if operator_ids.any?
  end
end
