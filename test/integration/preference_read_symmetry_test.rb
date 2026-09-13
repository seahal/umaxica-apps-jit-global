# typed: false
# frozen_string_literal: true

require "test_helper"

# The rendered theme/language value must come from the expected authority for
# the caller's state: the token-side preference for an anonymous visitor, and
# the same token-side preference (now adopted/synced with the resource mirror)
# once signed in. Both reads should agree on the value the user actually set.
class PreferenceReadSymmetryTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  end

  test "anonymous theme read reflects the value just written on the same anonymous session" do
    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success

    patch base_app_preference_theme_url(ri: "jp"),
          params: { preference_theme: { option_id: "dr" } }

    assert_response :redirect

    get base_app_web_v0_theme_url(ri: "jp")

    assert_response :success
    assert_equal "dr", response.parsed_body["theme"]
  end

  # The JS-readable `language` cookie is a write-only mirror for the browser. Rails resolves the
  # locale from the preference JWT (via Actor.preferences) and the `?lx` overlay only; a stale or
  # forged `language` cookie must not become a second source of truth that overrides it. The
  # resolution code is shared by the base, auth, and side application controllers.
  test "a conflicting language cookie does not override the region-seeded locale" do
    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = "en"

    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success
    assert_select "html[lang=?]", "ja"
  end

  test "a conflicting language cookie does not override an explicit saved language" do
    # An anonymous session that explicitly chose English on the language screen.
    get edit_base_app_preference_language_url(ri: "jp")
    patch base_app_preference_language_url(ri: "jp"),
          params: { preference_language: { option_id: AppPreferenceLanguageOption::EN.to_s } }

    assert_response :redirect

    cookies[PreferenceIoKeys::Cookies::LANGUAGE] = "ja"

    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success
    assert_select "html[lang=?]", "en"
  end

  test "signed-in theme read reflects the same token-side value after adoption" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    headers = {
      "Authorization" => "Bearer #{
        AuthenticationToken.encode(
          user, host: host, session_public_id: token.public_id, resource_type: "client",
                jwt_issuer_id: "surface:BASE_APP",
        )
      }",
    }

    patch base_app_preference_theme_url(ri: "jp"), headers: headers, as: :json,
                                                   params: { preference_theme: { option_id: "dr" } }

    assert_response :ok
    assert_equal "dr", response.parsed_body.dig("preference", "ct"),
                 "signed-in write's own response must reflect the value it just wrote"

    get base_app_web_v0_theme_url(ri: "jp"), headers: headers

    assert_response :success
    assert_equal "dr", response.parsed_body["theme"],
                 "signed-in read must reflect the value written through the same session"

    assert_equal "dr", user.reload.user_preference.theme,
                 "resource mirror (DB canonical for the signed-in user) must match the token-side write"
  end
end
