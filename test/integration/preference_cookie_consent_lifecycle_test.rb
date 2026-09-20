# typed: false
# frozen_string_literal: true

require "test_helper"

# Cookie consent is a recorded decision: granting it stamps when it was given, and withdrawing it
# clears that stamp so no stale consent time survives a later "no".
class PreferenceCookieConsentLifecycleTest < ActionDispatch::IntegrationTest
  test "granting consent records when it was given and withdrawing it clears the record" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_preference_path(ri: "jp")

    assert_response :success
    preference = AppPreference.order(:created_at).last

    patch base_app_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "1", functional: "1", performant: "0", targetable: "0" } }

    cookie = preference.reload.app_preference_cookie.reload

    assert_predicate cookie, :consented?
    assert_predicate cookie.consented_at, :present?

    patch base_app_preference_cookie_path(ri: "jp"),
          params: { preference_cookie: { consented: "0", functional: "0", performant: "0", targetable: "0" } }

    cookie.reload

    assert_not cookie.consented?
    assert_nil cookie.consented_at
  end
end
