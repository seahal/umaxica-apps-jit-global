# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationOtherSessionsRevokerTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::NOTHING)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::NOTHING)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.ensure_defaults!
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  test "a current APP evidence event authorizes revocation and remains reusable until its deadline" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
    )
    now = OpBaseAppRecord.database_now
    current = ClientToken.create!(
      authentication_epoch: client.authentication_epoch,
      user: client,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: now + 1.hour,
    )
    current.update!(root_login_established_at: now, established_authentication_method: "passkey")
    current.rotate_refresh_token!(now:)
    current.device_session_record!
    first_other = ClientToken.create!(
      authentication_epoch: client.authentication_epoch,
      user: client,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: now + 1.hour,
    )
    later = ClientToken.create!(
      authentication_epoch: client.authentication_epoch,
      user: client,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: now + 1.hour,
    )
    later.update!(created_at: now + 1.minute)

    oidc_client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i - 1
    grant = OpAppGrant.create!(
      authentication_epoch: current.authentication_epoch,
      client_token: current,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr,
      amr: ["passkey"],
      auth_time: auth_time,
      sid: grant.public_id,
      sub: OidcSubject.for(client, resource_type: "client"),
      client_id: oidc_client.client_id,
      aud: [oidc_client.aud],
      jti: grant.oidc_jti,
    )

    result = AuthenticationOtherSessionsRevoker.call(
      owner: client,
      sessions: client.client_tokens.session_inventory,
      current_token: current,
      current_session_public_id: current.public_id,
      step_up_evidence: evidence,
    )

    assert_predicate result, :success?
    assert_equal [first_other.public_id], result.revoked_tokens.map(&:public_id)
    assert_not_predicate first_other.reload, :currently_usable?
    assert_predicate current.reload, :currently_usable?
    assert_predicate later.reload, :currently_usable?
    assert_nil current.last_step_up_at

    second_other = ClientToken.create!(
      authentication_epoch: client.authentication_epoch,
      user: client,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: now + 1.hour,
    )
    # The first request correctly excludes a session created after its snapshot. Make it part of
    # the second request's snapshot so this also proves the OP evidence remains reusable.
    later.update_column(:created_at, OpBaseAppRecord.database_now - 1.second)
    second_result = AuthenticationOtherSessionsRevoker.call(
      owner: client,
      sessions: client.client_tokens.session_inventory,
      current_token: current,
      current_session_public_id: current.public_id,
      step_up_evidence: evidence,
    )

    assert_equal [later.public_id, second_other.public_id].sort, second_result.revoked_tokens.map(&:public_id).sort
    assert_nil grant.reload.revoked_at
    assert_equal evidence.jti, grant.reload.oidc_jti
  end

  test "a current ORG evidence event authorizes revocation for its own root" do
    operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
    )
    now = OpBaseOrgRecord.database_now
    current = OperatorToken.create!(
      authentication_epoch: operator.authentication_epoch,
      staff: operator,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: now + 1.hour,
    )
    current.update!(root_login_established_at: now, established_authentication_method: "passkey")
    current.rotate_refresh_token!(now:)
    current.device_session_record!
    other = OperatorToken.create!(
      authentication_epoch: operator.authentication_epoch,
      staff: operator,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: now + 1.hour,
    )
    oidc_client = OidcClientRegistry.find!("base-org-ww")
    auth_time = now.to_i - 1
    grant = OpOrgGrant.create!(
      authentication_epoch: current.authentication_epoch,
      operator_token: current,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr,
      amr: ["passkey"],
      auth_time: auth_time,
      sid: grant.public_id,
      sub: OidcSubject.for(operator, resource_type: "operator"),
      client_id: oidc_client.client_id,
      aud: [oidc_client.aud],
      jti: grant.oidc_jti,
    )

    result = AuthenticationOtherSessionsRevoker.call(
      owner: operator,
      sessions: operator.staff_tokens.session_inventory,
      current_token: current,
      current_session_public_id: current.public_id,
      step_up_evidence: evidence,
    )

    assert_equal [other.public_id], result.revoked_tokens.map(&:public_id)
    assert_not_predicate other.reload, :currently_usable?
    assert_predicate current.reload, :currently_usable?
  end

  test "missing or expired evidence leaves every other session usable" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
    )
    now = OpBaseAppRecord.database_now
    current = ClientToken.create!(
      authentication_epoch: client.authentication_epoch,
      user: client,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: now + 1.hour,
    )
    current.update!(root_login_established_at: now, established_authentication_method: "passkey")
    current.rotate_refresh_token!(now:)
    current.device_session_record!
    other = ClientToken.create!(
      authentication_epoch: client.authentication_epoch,
      user: client,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: now + 1.hour,
    )
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i - StepUpEvidenceValue::MAX_AGE_SECONDS - 1
    grant = OpAppGrant.create!(
      authentication_epoch: current.authentication_epoch,
      client_token: current,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    expired_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr,
      amr: ["passkey"],
      auth_time: auth_time,
      sid: grant.public_id,
      sub: OidcSubject.for(client, resource_type: "client"),
      client_id: oidc_client.client_id,
      aud: [oidc_client.aud],
      jti: grant.oidc_jti,
    )

    [nil, expired_evidence].each do |evidence|
      assert_raises(AuthenticationOtherSessionsRevoker::StepUpUnavailable) do
        AuthenticationOtherSessionsRevoker.call(
          owner: client,
          sessions: client.client_tokens.session_inventory,
          current_token: current,
          current_session_public_id: current.public_id,
          step_up_evidence: evidence,
        )
      end
      assert_predicate other.reload, :currently_usable?
    end
  end

  test "a missing current token is refused before any session changes" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
    )
    token = ClientToken.create!(
      authentication_epoch: client.authentication_epoch,
      user: client,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: 1.hour.from_now,
    )
    other = ClientToken.create!(
      authentication_epoch: client.authentication_epoch,
      user: client,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: 1.hour.from_now,
    )

    assert_raises(AuthenticationOtherSessionsRevoker::Denied) do
      AuthenticationOtherSessionsRevoker.call(
        owner: client,
        sessions: client.client_tokens.session_inventory,
        current_session_public_id: token.public_id,
      )
    end

    assert_predicate token.reload, :currently_usable?
    assert_predicate other.reload, :currently_usable?
  end
end
