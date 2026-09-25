# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # The preference token is issued to anonymous browsers and carries a session-like `sid`.
    # Authentication and authorization must read only the verified access token, so a preference
    # token presented in any access-token position never signs anyone in.
    class PreferenceTokenIsNotAnAccessTokenTest < ActionDispatch::IntegrationTest
      test "a preference token in the access cookie does not authenticate a protected route" do
        host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
        host! host
        patch base_app_preference_region_path(ri: "jp"),
              params: { preference_region: { option_id: "JP" } }

        assert_response :redirect
        preference_token = cookies[PreferenceCookieName.access(production: false, surface: :app)]

        assert_predicate preference_token, :present?

        cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = preference_token
        get base_app_identity_sessions_url(ri: "jp", host: host), headers: { "Accept" => "application/json" }

        assert_response :unauthorized
      end

      test "a preference token sent as a bearer token does not authenticate a protected route" do
        host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
        host! host
        patch base_app_preference_region_path(ri: "jp"),
              params: { preference_region: { option_id: "JP" } }

        assert_response :redirect
        preference_token = cookies[PreferenceCookieName.access(production: false, surface: :app)]

        assert_predicate preference_token, :present?

        get base_app_identity_sessions_url(ri: "jp", host: host),
            headers: { "Accept" => "application/json", "Authorization" => "Bearer #{preference_token}" }

        assert_response :unauthorized
      end
    end
  end
end
