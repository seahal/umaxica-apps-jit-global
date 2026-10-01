# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Settings::EntrasControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_token_binding_methods,
           :operator_token_kinds, :operator_token_statuses, :operator_token_dbsc_statuses,
           :operator_mfa_levels, :operator_mfa_statuses, :operator_visibilities

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    host! @host
    @operator = operators(:one)
    @operator.update!(status_id: OperatorStatus::ACTIVE)
    @token = OperatorToken.create!(staff: @operator, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    @token.rotate_refresh_token!
    @headers = {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @operator.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
      "Authorization" => "Bearer #{
        jwt_access_token_for(@operator, host: @host, session_public_id: @token.public_id, resource_type: "operator")
      }",
    }

    OrganizationEntraConnectionState.ensure_defaults!
    OperatorEntraIdentityState.ensure_defaults!
  end

  test "show is read only" do
    get auth_org_settings_entra_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_equal "auth/org/settings/entras/show", inertia_component
    assert_equal auth_org_settings_path(ri: "jp"), inertia_props.fetch("back_link").fetch("href")
    assert_equal edit_auth_org_settings_entra_path(ri: "jp"), inertia_props.fetch("edit_link").fetch("href")
    # The read-only screen offers no connect form at all.
    assert_nil inertia_props["form"]
  end

  # A correctly configured single-tenant deployment holds no
  # OrganizationEntraConnection rows, so the screen must offer the ceremony
  # without one. It used to render a form per connection row, which meant the
  # normal configuration showed no button at all while /social/entra/session/new
  # worked.
  test "edit offers the Entra ceremony with no connection record present" do
    assert_equal 0, OrganizationEntraConnection.count

    get edit_auth_org_settings_entra_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_equal "auth/org/settings/entras/edit", inertia_component
    assert_equal auth_org_settings_entra_path(ri: "jp"), inertia_props.fetch("form").fetch("action")
    assert_nil inertia_props.fetch("unavailable_notice")
  end

  test "edit offers no form and explains why when the provider is unavailable" do
    with_entra_unavailable do
      get edit_auth_org_settings_entra_url(ri: "jp"), headers: @headers
    end

    assert_response :success
    assert_nil inertia_props.fetch("form")
    assert_equal I18n.t("sign.org.authentication.entra.errors.provider_unavailable"),
                 inertia_props.fetch("unavailable_notice")
  end

  test "create redirects to the org Entra sign in ceremony" do
    post auth_org_settings_entra_url(ri: "jp"), headers: @headers

    assert_response :see_other
    assert_equal new_auth_org_social_entra_session_url(ri: "jp"), response.location
  end

  # Parity with Auth::Org::Social::SessionsController#create: the kill switch
  # has to stop this entry point too, not only the one on the sign-in page.
  test "create refuses to start the ceremony when the provider is unavailable" do
    with_entra_unavailable do
      post auth_org_settings_entra_url(ri: "jp"), headers: @headers
    end

    assert_response :service_unavailable
    assert_equal "auth/org/settings/entras/edit", inertia_component
    assert_nil inertia_props.fetch("form")
  end

  test "settings route uses create and destroy" do
    route = Rails.application.routes.recognize_path(
      "http://#{@host}/settings/entra",
      method: :post,
    )

    assert_equal "auth/org/settings/entras", route[:controller]
    assert_equal "create", route[:action]

    route = Rails.application.routes.recognize_path(
      "http://#{@host}/settings/entra",
      method: :delete,
    )

    assert_equal "auth/org/settings/entras", route[:controller]
    assert_equal "destroy", route[:action]
  end

  private

  # Mirrors the stub in
  # test/controllers/auth/org/omniauth/omniauth_callbacks_controller_test.rb.
  def with_entra_unavailable(&)
    disabled = Object.new
    disabled.define_singleton_method(:start_decision) { |**|
      ExternalAuthentication::AvailabilityDecision.new(
        state: :disabled, source: "test", configuration_version: nil, reason_code: "test_disabled",
        incident_id: nil, observed_at: Time.current,
      )
    }
    ExternalAuthentication::ProviderAvailabilityFactory.stub(:current, disabled, &)
  end

  def jwt_access_token_for(resource, host:, session_public_id:, resource_type:)
    AuthenticationToken.encode(
      resource,
      host: host,
      session_public_id: session_public_id,
      resource_type: resource_type,
      jwt_issuer_id: "surface:AUTH_ORG",
    )
  end
end
