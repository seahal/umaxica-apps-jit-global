# typed: false
# frozen_string_literal: true

require "test_helper"

# Logout keeps guest-safe display preferences (language/timezone/theme) as
# designed: they are written from the token-side preference regardless of
# sign-in state, so there is no separate "signed-in" copy to purge. Auth
# transport cookies (the session/refresh credentials) are the only things a
# logout must clear.
class PreferenceLogoutDowngradeTest < ActionDispatch::IntegrationTest
  setup do
    https!
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  end

  test "logout keeps guest-safe display cookies and clears the session cookie" do
    user = clients(:one)
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get edit_base_app_preference_theme_url(ri: "jp"),
        headers: { "X-TEST-CURRENT-USER" => user.id.to_s, "X-TEST-SESSION-PUBLIC-ID" => token.public_id }

    assert_response :success

    patch base_app_preference_theme_url(ri: "jp"),
          headers: { "X-TEST-CURRENT-USER" => user.id.to_s, "X-TEST-SESSION-PUBLIC-ID" => token.public_id },
          params: { preference_theme: { option_id: "dr" } }

    assert_response :redirect

    theme_cookie_before = cookies[PreferenceBase::THEME_COOKIE_KEY]

    assert_equal "dr", theme_cookie_before

    post base_app_sign_out_url,
         headers: { "X-TEST-CURRENT-USER" => user.id.to_s, "X-TEST-SESSION-PUBLIC-ID" => token.public_id }

    assert_response :see_other
    assert_equal "/lobby", URI.parse(response.location).path
    assert_equal "dr", cookies[PreferenceBase::THEME_COOKIE_KEY],
                 "guest-safe display preference must survive logout (contract: keep-values)"
  end

  test "logout does not delete or reset the preference record's stored values" do
    get edit_base_app_preference_theme_url(ri: "jp")

    assert_response :success

    patch base_app_preference_theme_url(ri: "jp"),
          params: { preference_theme: { option_id: "dr" } }

    assert_response :redirect

    preference = AppPreference.order(:created_at).last
    theme_option_id_before = preference.app_preference_theme.option_id

    # No resolved session: sign-out is a no-op that redirects to the lobby.
    post base_app_sign_out_url

    assert_response :see_other
    assert_equal "/lobby", URI.parse(response.location).path

    preference.reload

    assert_equal theme_option_id_before, preference.app_preference_theme.option_id
    assert_not_equal AppPreferenceStatus::DELETED, preference.status_id
  end
end
