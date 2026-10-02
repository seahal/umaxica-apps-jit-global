# typed: false
# frozen_string_literal: true

require "test_helper"

# A signed-in request that arrives without a browser preference record creates
# one, and that creation reconciles it with the principal's own preference
# (PreferenceTransport#restore_preference_from_resource! -> PreferenceAdoption).
# These pin what the reconciliation does to the stored records on a new browser
# session, and that an anonymous session keeps serving its own value.
class PreferenceAdoptionOnSignInTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses,
           :app_preference_chronicle_events, :app_preference_chronicle_levels

  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @user = clients(:one)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    @headers = {
      "Authorization" => "Bearer #{AuthenticationToken.encode(
        @user, host: @host, session_public_id: @token.public_id,
               resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
      )}",
      "Accept" => "application/json",
    }.freeze
  end

  test "a signed-in theme write reaches the principal's own preference record" do
    patch base_app_preference_theme_url(ri: "jp"), headers: @headers, as: :json,
                                                   params: { preference_theme: { option_id: "dr" } }

    assert_response :ok
    assert_equal "dr", @user.reload.user_preference.theme
  end

  test "a signed-in language write reaches the principal's own preference record" do
    patch base_app_preference_language_url(ri: "jp"), headers: @headers, as: :json,
                                                      params: { preference_language: { option_id: "en" } }

    assert_response :redirect
    assert_equal "en", @user.reload.user_preference.language
  end

  test "a fresh browser session reconciles against the principal record without losing it" do
    patch base_app_preference_theme_url(ri: "jp"), headers: @headers, as: :json,
                                                   params: { preference_theme: { option_id: "dr" } }

    assert_response :ok

    reset!
    https!
    host! @host

    get base_app_api_v0_preferences_theme_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_predicate response.parsed_body["theme"], :present?
    assert_equal "dr", @user.reload.user_preference.theme
  end

  test "a fresh browser session for a signed-in principal answers a theme and keeps the principal record" do
    reset!
    https!
    host! @host

    get base_app_api_v0_preferences_theme_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_predicate response.parsed_body["theme"], :present?
    assert_predicate @user.reload.user_preference, :present?
  end

  test "an anonymous browser session serves the value it just wrote" do
    patch base_app_preference_theme_url(ri: "jp"), params: { preference_theme: { option_id: "dr" } }

    assert_response :redirect

    get base_app_api_v0_preferences_theme_url(ri: "jp")

    assert_response :success
    assert_equal "dr", response.parsed_body["theme"]
  end

  test "a signed-in cookie consent write reaches the principal's own preference record" do
    patch base_app_preference_cookie_url(ri: "jp"), headers: @headers, as: :json,
                                                    params: {
                                                      preference_cookie: {
                                                        consented: "1",
                                                        functional: "1",
                                                        performant: "1",
                                                        targetable: "0",
                                                      },
                                                    }

    assert_response :ok
    preference = @user.reload.user_preference

    assert preference.consented
    assert preference.functional
    assert_not preference.targetable
  end
  test "a fresh browser session takes over the principal's explicit language and recorded consent" do
    patch base_app_preference_language_url(ri: "jp"), headers: @headers, as: :json,
                                                      params: { preference_language: { option_id: "en" } }
    patch base_app_preference_cookie_url(ri: "jp"), headers: @headers, as: :json,
                                                    params: {
                                                      preference_cookie: {
                                                        consented: "1",
                                                        functional: "1",
                                                        performant: "1",
                                                        targetable: "0",
                                                      },
                                                    }

    assert_predicate @user.reload.user_preference, :present?

    reset!
    https!
    host! @host

    get base_app_api_v0_preferences_theme_url(ri: "jp"), headers: @headers

    assert_response :success
    browser = AppPreference.order(:created_at).last

    assert_equal AppPreferenceLanguageOption::EN, browser.app_preference_language.option_id
    cookie = browser.app_preference_cookie

    assert_predicate cookie, :consented?
    assert_predicate cookie, :functional?
    assert_predicate cookie, :performant?
    assert_not_predicate cookie, :targetable?
  end
end
