# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationSessionRevokerTest < ActiveSupport::TestCase
  class FakeRelation
    def initialize(tokens)
      @tokens = tokens
    end

    def find_each
      @tokens.each { |token| yield token }
    end
  end

  test "tokens_for returns the matching token relation for client and staff resource types" do
    user = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 2)

    assert_equal ClientToken.where(user_id: 1).to_sql, AuthenticationSessionRevoker.tokens_for(user).to_sql
    assert_equal OperatorToken.where(staff_id: 2).to_sql, AuthenticationSessionRevoker.tokens_for(staff).to_sql
  end

  test "tokens_for rejects unsupported resource types" do
    error = assert_raises(ArgumentError) { AuthenticationSessionRevoker.tokens_for(Object.new) }

    assert_match(/Unsupported resource type/, error.message)
  end

  test "revoke_all_for delegates each token to the authority stop writer" do
    tokens = [Object.new, Object.new]
    resource = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, id: 1)
    relation = FakeRelation.new(tokens)
    calls = []

    AuthenticationSessionRevoker.stub(:tokens_for, relation) do
      AuthenticationLogoutCurrentSession.stub(:call, ->(**arguments) { calls << arguments }) do
        AuthenticationSessionRevoker.revoke_all_for(resource)
      end
    end

    assert_equal tokens, calls.map { |arguments| arguments.fetch(:token) }
    assert_equal [resource, resource], calls.map { |arguments| arguments.fetch(:resource) }
    assert_equal ["session_revoke_all", "session_revoke_all"], calls.map { |arguments| arguments.fetch(:reason) }
    assert_equal ["revoke_others", "revoke_others"], calls.map { |arguments| arguments.fetch(:cause) }
  end

  test "tokens_for_method returns sessions matching the method and sessions with no recorded method" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    matching = ClientToken.create!(
      authentication_epoch: 0, user_id: client.id,
      established_authentication_method: "passkey",
    )
    unattributed = ClientToken.create!(
      authentication_epoch: 0, user_id: client.id,
      established_authentication_method: nil,
    )
    other_method = ClientToken.create!(
      authentication_epoch: 0, user_id: client.id,
      established_authentication_method: "email",
    )

    result_ids = AuthenticationSessionRevoker.tokens_for_method(client, "passkey").pluck(:id)

    assert_includes result_ids, matching.id
    assert_includes result_ids, unattributed.id
    assert_not_includes result_ids, other_method.id
  end

  test "tokens_for_method additionally includes TOTP step-up sessions only when the method is totp" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    totp_matching = ClientToken.create!(
      authentication_epoch: 0, user_id: client.id,
      established_authentication_method: "totp",
    )
    passkey_with_totp_step_up = ClientToken.create!(
      authentication_epoch: 0,
      user_id: client.id,
      established_authentication_method: "passkey",
      last_step_up_method: "totp",
      last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
    )
    passkey_without_step_up = ClientToken.create!(
      authentication_epoch: 0, user_id: client.id,
      established_authentication_method: "passkey",
    )

    totp_result_ids = AuthenticationSessionRevoker.tokens_for_method(client, "totp").pluck(:id)
    passkey_result_ids = AuthenticationSessionRevoker.tokens_for_method(client, "passkey").pluck(:id)

    assert_includes totp_result_ids, totp_matching.id
    assert_includes totp_result_ids, passkey_with_totp_step_up.id
    assert_includes passkey_result_ids, passkey_with_totp_step_up.id
    assert_not_includes passkey_result_ids, totp_matching.id
    assert_not_includes totp_result_ids, passkey_without_step_up.id
  end

  test "TOTP revocation includes legacy attribution or the latest commit fact across all grants" do
    now = OpBaseAppRecord.database_now
    cases = [
      {
        legacy_method: "totp",
        expected: true,
        grants: [{ method: "passkey", committed_at: now, state: :live }],
      },
      {
        legacy_method: "passkey",
        expected: true,
        grants: [{ method: "totp", committed_at: now, state: :live }],
      },
      {
        legacy_method: "totp",
        expected: true,
        grants: [{ method: "totp", committed_at: now, state: :live }],
      },
      {
        legacy_method: "passkey",
        expected: false,
        grants: [{ method: "email_otp", committed_at: now, state: :live }],
      },
      {
        legacy_method: "passkey",
        expected: true,
        grants: [
          { method: nil, committed_at: now - 1.second, state: :live },
          { method: "totp", committed_at: now, state: :expired },
        ],
      },
      {
        legacy_method: "passkey",
        expected: true,
        grants: [
          { method: nil, committed_at: now - 1.second, state: :live },
          { method: "totp", committed_at: now, state: :revoked },
        ],
      },
      {
        legacy_method: "passkey",
        expected: false,
        grants: [
          { method: "totp", committed_at: now - 1.second, state: :live },
          { method: "passkey", committed_at: now, state: :live },
        ],
      },
    ]
    cases.each do |definition|
      client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(
        authentication_epoch: client.authentication_epoch,
        user: client,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
        discard_at: now + 1.hour,
        last_step_up_method: definition.fetch(:legacy_method),
      )
      token.update!(root_login_established_at: now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now:)
      token.device_session_record!

      definition.fetch(:grants).each do |grant_spec|
        grant = OpAppGrant.create!(
          authentication_epoch: token.authentication_epoch,
          client_token: token,
          oidc_client_id: "step-up-test-#{SecureRandom.hex(8)}",
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: now,
          oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
          oidc_amr: JSON.generate(["passkey"]),
          refresh_token_expires_at: now + 1.hour,
        )
        grant.issue_refresh_token!(now:)
        case grant_spec.fetch(:state)
        when :live
          nil
        when :expired
          grant.update!(refresh_token_expires_at: now - 1.second)
        when :revoked
          grant.update!(revoked_at: now)
        else
          raise ArgumentError, "unsupported grant state: #{grant_spec.fetch(:state).inspect}"
        end
        next unless grant_spec.fetch(:method)

        ClientStepUpCommit.create!(
          grant: grant,
          root_token: token,
          context_ref: PublicId.generate,
          verified_method: grant_spec.fetch(:method),
          committed_at: grant_spec.fetch(:committed_at),
        )
      end
      result_ids = AuthenticationSessionRevoker.tokens_for_method(client, "totp").pluck(:id)

      assert_equal definition.fetch(:expected), result_ids.include?(token.id),
                   "legacy_method=#{definition.fetch(:legacy_method)} grants=#{definition.fetch(:grants).inspect}"
    end
  end

  test "TOTP revocation reads the latest OP commit fact for an ORG root" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    now = OpBaseOrgRecord.database_now
    token = OperatorToken.create!(
      authentication_epoch: operator.authentication_epoch,
      staff: operator,
      discard_at: now + 1.hour,
      last_step_up_method: "passkey",
    )
    token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch,
      operator_token: token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["totp"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    OperatorStepUpCommit.create!(
      grant: grant,
      root_token: token,
      context_ref: PublicId.generate,
      verified_method: "totp",
      committed_at: now,
    )

    result_ids = AuthenticationSessionRevoker.tokens_for_method(operator, "totp").pluck(:id)

    assert_includes result_ids, token.id
  end
end
