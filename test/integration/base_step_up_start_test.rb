# frozen_string_literal: true

require "test_helper"
require_relative "../support/rp_cell_session_helper"

class BaseStepUpStartTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper

  test "Base APP GET is read-only and POST starts the OP-mediated ceremony on its RP session" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    ClientPasskey.create!(
      user: actor,
      webauthn_id: SecureRandom.uuid,
      external_id: SecureRandom.uuid,
      public_key: "base-app-step-up-public-key",
      sign_count: 0,
      description: "Step-up test passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    root_token = authentication_harness_create_token(actor)
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!

    as_rp_cell("base-app-ww") do
      _token_response, _payload, rp_session = sign_in_rp_cell("base-app-ww", actor:, root_token:)
      initial_states = RpStepUpState.where(rp_session:).count
      initial_outboxes = RpStepUpAuditOutbox.count

      get base_app_verification_path(ri: "jp")

      assert_response :success
      assert_includes response.headers.fetch("Cache-Control"), "private"
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_includes response.body, '"return_target":"/identity"'
      assert_equal initial_states, RpStepUpState.where(rp_session:).count
      assert_equal initial_outboxes, RpStepUpAuditOutbox.count

      ["https://attacker.example/", "//attacker.example", "/sign/out", "", ["/identity"]].each do |target|
        post base_app_verification_path(ri: "jp"), params: { return_target: target }

        assert_response :bad_request, target.inspect
        assert_equal initial_states, RpStepUpState.where(rp_session:).count
        assert_equal initial_outboxes, RpStepUpAuditOutbox.count
      end

      post base_app_verification_path(ri: "jp"), params: { return_target: "/settings/birthdate" }

      assert_response :see_other
      assert_includes response.headers.fetch("Cache-Control"), "private"
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      state = RpStepUpState.find_by!(rp_session:)
      outbox = RpStepUpAuditOutbox.find_by!(context_ref: state.public_id)
      authorization_uri = URI.parse(response.location)
      if authorization_uri.host == "jump.umaxica.net"
        jump_token = Rack::Utils.parse_nested_query(authorization_uri.query).fetch("rt")
        jump_claims, = JWT.decode(jump_token, nil, false)
        authorization_uri = URI.parse(jump_claims.fetch("url"))
      end

      assert_equal URI.parse(OidcIssuer.authorization_endpoint("client")).path, authorization_uri.path
      assert_equal "base-app-ww", Rack::Utils.parse_query(authorization_uri.query).fetch("client_id")
      assert_equal "/settings/birthdate", state.return_target
      assert_equal RpStepUpStateStatus::PENDING, state.state_id
      assert_equal RpStepUpStateStatus::PENDING, state.reload.state_id
      assert_equal rp_session.installed_generation, state.initiating_generation
      assert_equal "step_up.requested", outbox.event_type
      assert_equal rp_session.id, state.rp_session_id
      assert_nil rp_session.reload.revoked_at
    end
  end

  test "Base ORG starts through its separate RP cell and OP registration" do
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskey.create!(
      staff: actor,
      webauthn_id: SecureRandom.uuid,
      external_id: SecureRandom.uuid,
      public_key: "base-org-step-up-public-key",
      sign_count: 0,
      description: "Step-up test passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    root_token = authentication_harness_create_token(actor)
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    https!

    as_rp_cell("base-org-ww") do
      _token_response, _payload, rp_session = sign_in_rp_cell("base-org-ww", actor:, root_token:)

      post base_org_verification_path(ri: "jp"), params: { return_target: "/settings/birthdate" }

      assert_response :see_other
      state = RpBaseOrgStepUpState.find_by!(rp_session:)
      outbox = RpBaseOrgStepUpAuditOutbox.find_by!(context_ref: state.public_id)
      authorization_uri = URI.parse(response.location)
      if authorization_uri.host == "jump.umaxica.net"
        jump_token = Rack::Utils.parse_nested_query(authorization_uri.query).fetch("rt")
        jump_claims, = JWT.decode(jump_token, nil, false)
        authorization_uri = URI.parse(jump_claims.fetch("url"))
      end

      assert_equal URI.parse(OidcIssuer.authorization_endpoint("operator")).path, authorization_uri.path
      assert_equal "base-org-ww", Rack::Utils.parse_query(authorization_uri.query).fetch("client_id")
      assert_equal "/settings/birthdate", state.return_target
      assert_equal RpBaseOrgStepUpStateStatus::PENDING, state.state_id
      assert_equal "step_up.requested", outbox.event_type
      assert_nil rp_session.reload.revoked_at
    end
  end

  test "Base ORG standby context refuses step-up before creating RP state" do
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    root_token = authentication_harness_create_token(actor)
    root_token.update!(authentication_context: AuthenticationContextValue::STANDBY_KEY)
    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    https!

    as_rp_cell("base-org-ww") do
      _token_response, _payload, rp_session = sign_in_rp_cell("base-org-ww", actor:, root_token:)
      states_before = RpBaseOrgStepUpState.where(rp_session:).count
      outboxes_before = RpBaseOrgStepUpAuditOutbox.count

      post base_org_verification_path(ri: "jp"), params: { return_target: "/settings/birthdate" }

      assert_response :forbidden
      assert_equal states_before, RpBaseOrgStepUpState.where(rp_session:).count
      assert_equal outboxes_before, RpBaseOrgStepUpAuditOutbox.count
    end
  end
end
