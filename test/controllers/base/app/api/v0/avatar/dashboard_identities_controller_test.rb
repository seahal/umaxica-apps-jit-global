# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::Api::V0::Avatar::DashboardIdentitiesControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @other_actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @actor)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @other_actor)
    @own_candidate = BaseSwitcherAuthority.new(surface: :app, principal: @actor)
      .selectable_candidates.fetch(0).fetch(:public)
    @other_candidate = BaseSwitcherAuthority.new(surface: :app, principal: @other_actor)
      .selectable_candidates.fetch(0).fetch(:public)
    @root = ClientToken.new(user: @actor, authentication_epoch: 0)
    @grant = Object.new
    @grant.define_singleton_method(:active?) { true }
    @grant.define_singleton_method(:parent_token) { @root }
    @auth = OidcAccessTokenAuthenticator::Result.new(
      success: true,
      payload: { "client_id" => "base-app-ww", "sid" => "owner-api-test-grant" },
      token: @root,
      resource: @actor,
      error: nil,
    )

    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
  end

  test "owner resolves the RP-selected persona and returns its display name and avatar version" do
    own_persona = ClientPersona.find_by!(public_id: @own_candidate.fetch(:account_public_id))
    own_persona.update!(moniker: "Owner-resolved persona")

    with_authenticated_owner do
      get "/api/v0/avatar/app/dashboard-identity", params: owner_params(@own_candidate),
                                                   headers: owner_headers
    end

    assert_response :success
    assert_equal "Owner-resolved persona", response.parsed_body.fetch("display_name")
    assert_equal "default", response.parsed_body.fetch("image_version")
  end

  test "owner refuses a foreign persona even when the OP root names it" do
    @root.selected_account_public_id = @other_candidate.fetch(:account_public_id)

    with_authenticated_owner do
      get "/api/v0/avatar/app/dashboard-identity", params: owner_params(@other_candidate),
                                                   headers: owner_headers
    end

    assert_response :forbidden
    assert_equal "forbidden", response.parsed_body.fetch("error")
  end

  private

  def owner_params(selection)
    {
      persona: selection.fetch(:account_public_id),
      organization_public_id: selection.fetch(:organization_public_id),
      organization_unit_public_id: selection.fetch(:organization_unit_public_id),
      avatar_public_id: selection.fetch(:avatar_public_id),
    }
  end

  def owner_headers
    { "Authorization" => "Bearer owner-api-test-access-token", "X-Client-Assertion" => "owner-api-test-assertion" }
  end

  # Replace only the verified transport identities at this API boundary; candidate membership,
  # persona resolution, avatar selection and response generation remain real owner behavior.
  def with_authenticated_owner
    OidcClientRegistry.stub(:authenticate_assertion, true) do
      OidcAccessTokenAuthenticator.stub(:call, @auth) do
        OpAppGrant.stub(:find_by, @grant) { yield }
      end
    end
  end
end
