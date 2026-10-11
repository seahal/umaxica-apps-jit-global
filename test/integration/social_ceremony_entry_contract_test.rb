# typed: false
# frozen_string_literal: true

require "test_helper"

# The social ceremony entry has two shapes and they must not blur into one:
#
#   POST /social/:provider/session      in-application buttons; the press supplies
#                                       the CSRF token, so the ceremony starts and
#                                       hands the same POST to the OmniAuth request
#                                       phase with a 307
#   GET  /social/:provider/session/new  arrivals that can only be a GET (shared
#                                       links, bookmarks, external sites); nothing
#                                       is sent to the provider until a person
#                                       presses the button
#
# A GET carries no CSRF token, so a GET that started the ceremony on its own would
# be login CSRF (CVE-2015-9284): a link in an email or on another site could sign
# a visitor into an account they did not choose. That is why the request phase is
# POST-only and why the cushion page must not submit itself.
class SocialCeremonyEntryContractTest < ActionDispatch::IntegrationTest
  PROVIDERS = %w(google apple).freeze

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! @host
  end

  PROVIDERS.each do |provider|
    test "#{provider} in-application entry hands the POST to the OmniAuth request phase with a 307" do
      post public_send(:"auth_app_social_#{provider}_session_path", ri: "jp"),
           headers: { "Host" => @host }

      # 307 preserves the method and the body, so the authenticity token the
      # button carried reaches the request phase, which verifies it again.
      assert_response :temporary_redirect
      assert_equal "/social/#{provider}", URI.parse(response.location).path
    end

    test "#{provider} sign-up entry hands the POST to the OmniAuth request phase with a 307" do
      post public_send(:"auth_app_social_#{provider}_registration_path", ri: "jp"),
           headers: { "Host" => @host }

      assert_response :temporary_redirect
      assert_equal "/social/#{provider}", URI.parse(response.location).path
    end

    test "#{provider} ceremony cannot be started by a GET" do
      # Only :create is routed, and only as POST. A GET entry carries no token,
      # so a link could start a ceremony: that is the vulnerability this route
      # shape exists to prevent. There is no landing page to add back.
      %W(/social/#{provider}/session /social/#{provider}/session/new
         /social/#{provider}/registration /social/#{provider}/registration/new).each do |path|
        assert_raises(ActionController::RoutingError, "#{path} must not be reachable by GET") do
          Rails.application.routes.recognize_path(path, method: :get)
        end
      end
    end

    test "#{provider} button token is accepted by the OmniAuth request phase" do
      # The token is verified twice, at two different paths: here and again at
      # /social/:provider after the 307. A per-form token is bound to one path
      # and method, so it would pass the first check and fail the second,
      # breaking the handoff for every user. Only a global token survives both.
      issuance = OidcAuthorizationTransactionCoordinator.issue!(
        surface: "app",
        intent: "sign_in",
        params: {
          response_type: "code",
          client_id: "core-app",
          redirect_uri: OidcClientRegistry.find!("core-app").redirect_uris.first,
          code_challenge: "challenge",
          code_challenge_method: "S256",
          state: "state",
          nonce: "nonce",
          scope: "openid profile",
        },
      )
      get auth_app_sign_in_path(
        ri: "jp",
        admission: BaseAuthAdmissionCoordinator.issue_handoff!(transaction: issuance.transaction).code,
      ), headers: { "Host" => @host }

      assert_response :see_other
      follow_redirect!

      assert_response :success

      token = social_button_token(provider)

      assert_predicate token, :present?, "sign-in page carries no authenticity token for #{provider}"

      with_forgery_protection do
        post "/social/#{provider}",
             params: { authenticity_token: token },
             headers: { "Host" => @host, "Sec-Fetch-Site" => "same-origin" }
      end

      assert_response :redirect,
                      "the request phase rejected the request the sign-in button makes"
      assert_match(/\Ahttps:/, response.location)
    end

    test "#{provider} request phase rejects a cross-site submission" do
      # Login CSRF (CVE-2015-9284): a form on another site must not be able to
      # start the ceremony. This also keeps the assertion above from going
      # vacuous, since forgery protection is off by default in this environment.
      with_forgery_protection do
        post "/social/#{provider}",
             params: { authenticity_token: "not-a-real-token" },
             headers: { "Host" => @host, "Sec-Fetch-Site" => "cross-site" }
      end

      # The request phase rejects it, so OmniAuth routes to the failure endpoint
      # instead of the provider.
      assert_response :redirect
      assert_no_match(
        %r{accounts\.google\.com|appleid\.apple\.com}, response.location.to_s,
        "a cross-site submission reached the provider: login CSRF is not being blocked",
      )
    end
  end

  private

  # config/environments/test.rb keeps forgery protection off so the suite can
  # migrate in batches, which makes every CSRF assertion vacuous by default.
  # These requests opt back in.
  def with_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  def social_button_token(provider)
    action = public_send(:"auth_app_social_#{provider}_session_path", ri: "jp")
    button = inertia_props.fetch("social_providers").find { |entry| entry.fetch("action") == action }

    button&.fetch("authenticity_token")
  end
end
