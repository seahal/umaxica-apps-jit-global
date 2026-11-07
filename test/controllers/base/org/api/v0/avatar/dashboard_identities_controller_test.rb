# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Api::V0::Avatar::DashboardIdentitiesControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @other_actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @actor)
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @other_actor)
    @own_candidate = BaseSwitcherAuthority.new(surface: :org, principal: @actor)
      .selectable_candidates.fetch(0).fetch(:public)
    @other_candidate = BaseSwitcherAuthority.new(surface: :org, principal: @other_actor)
      .selectable_candidates.fetch(0).fetch(:public)
    Agent.find_by!(public_id: @own_candidate.fetch(:account_public_id)).update!(moniker: "Owner-resolved ORG persona")
    @root = OperatorToken.new(
      staff: @actor,
      authentication_epoch: 0,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    @grant = Minitest::Mock.new
    @auth = OidcAccessTokenAuthenticator::Result.new(
      success: true,
      payload: { "client_id" => "base-org-ww", "sid" => "owner-api-test-grant" },
      token: @root,
      resource: @actor,
      error: nil,
    )

    host! ENV.fetch("PUBLIC_BASE_STAFF_URL")
    https!
  end

  test "owner validates the RP-selected ORG persona against the authenticated operator" do
    params = {
      persona: @own_candidate.fetch(:account_public_id),
      organization_public_id: @own_candidate.fetch(:organization_public_id),
      organization_unit_public_id: @own_candidate.fetch(:organization_unit_public_id),
      avatar_public_id: @own_candidate.fetch(:avatar_public_id),
    }
    @grant.expect(:active?, true)
    @grant.expect(:parent_token, @root)

    OidcClientRegistry.stub(:authenticate_assertion, true) do
      OidcAccessTokenAuthenticator.stub(:call, @auth) do
        OpOrgGrant.stub(:find_by, @grant) do
          get "/api/v0/avatar/org/dashboard-identity", params: params, headers: {
            "Authorization" => "Bearer owner-api-test-access-token",
            "X-Client-Assertion" => "owner-api-test-assertion",
          }
        end
      end
    end

    assert_response :success
    assert_equal "Owner-resolved ORG persona", response.parsed_body.fetch("display_name")
    assert_nil response.parsed_body.fetch("image_version")
    assert_mock @grant
  end

  test "owner refuses another operator's ORG persona even when the OP root names it" do
    @root.selected_account_public_id = @other_candidate.fetch(:account_public_id)
    params = {
      persona: @other_candidate.fetch(:account_public_id),
      organization_public_id: @other_candidate.fetch(:organization_public_id),
      organization_unit_public_id: @other_candidate.fetch(:organization_unit_public_id),
      avatar_public_id: @other_candidate.fetch(:avatar_public_id),
    }
    @grant.expect(:active?, true)
    @grant.expect(:parent_token, @root)

    OidcClientRegistry.stub(:authenticate_assertion, true) do
      OidcAccessTokenAuthenticator.stub(:call, @auth) do
        OpOrgGrant.stub(:find_by, @grant) do
          get "/api/v0/avatar/org/dashboard-identity", params: params, headers: {
            "Authorization" => "Bearer owner-api-test-access-token",
            "X-Client-Assertion" => "owner-api-test-assertion",
          }
        end
      end
    end

    assert_response :forbidden
    assert_equal "forbidden", response.parsed_body.fetch("error")
    assert_mock @grant
  end
end
