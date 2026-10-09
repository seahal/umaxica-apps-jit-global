# typed: false
# frozen_string_literal: true

require "test_helper"

# Legacy signed LOGIN results carry no admission binding and cannot establish Root
# authority. LINK results remain management inputs on Auth, never Base login inputs.
class SocialCompletionSignupHandoffTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @now = Time.current
    @session_ref = SecureRandom.uuid
    @uid = "signup-handoff-#{SecureRandom.hex(6)}"
    @original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    @client = clients(:one)
    @client.update_columns(birthdate: nil)
    ClientGoogleIdentity.create!(
      user: @client,
      uid: @uid,
      provider: "google",
      token: "provider-token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_forgery_protection
  end

  test "a legacy login result for an incomplete account cannot bypass admission" do
    travel_to(@now) do
      result_token = issue_login_result

      assert_no_difference [-> { ClientSignUpFlow.where(principal_id: @client.id).count }, "ClientToken.count"] do
        begin
          fv5017 = result_token
          fv5016 = "google"
          fv5015 = SocialCeremonyResultAdapter.new.issue!(
            token: fv5017,
            expires_at: @now + 1.minute,
            now: @now,
          )
          host!(@base_host)
          https!
          get(
            base_app_social_authentication_completion_path(
              id: fv5016,
              result_ref: fv5015,
              ri: "jp",
            ),
          )

          assert_response :success

          fv5013 = response.parsed_body.at_css("form")

          assert fv5013
          fv5012 =
            fv5013.css("input[name]").to_h { |fv5014|
              [fv5014["name"], fv5014["value"]]
            }
          post(
            fv5013["action"],
            params: fv5012,
            headers: {
              "Host" => @base_host,
              "Origin" => "https://#{@base_host}",
              "Sec-Fetch-Site" => "same-origin",
            },
          )
        end
      end

      assert_response :unprocessable_content
      assert_nil response.headers["Location"]
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
      transaction = ClientSocialCeremonyTransaction.order(:created_at).last

      assert_nil transaction.consumed_at
      assert_equal @client.id, ClientGoogleIdentity.find_by!(uid: @uid).user_id
    end
  end

  # This endpoint is the login-only completion path. A link completion posted here
  # is refused before any trust decision, and sent back to the provider's settings
  # page instead of being processed.
  test "a link completion posted to the login endpoint is sent back to settings" do
    travel_to(@now) do
      assert_no_difference -> { ClientSignUpFlow.where(principal_id: @client.id).count } do
        begin
          fv5011 = issue_link_result
          fv5010 = "google"
          fv5009 = SocialCeremonyResultAdapter.new.issue!(
            token: fv5011,
            expires_at: @now + 1.minute,
            now: @now,
          )
          host!(@base_host)
          https!
          get(
            base_app_social_authentication_completion_path(
              id: fv5010,
              result_ref: fv5009,
              ri: "jp",
            ),
          )

          assert_response :success

          fv5007 = response.parsed_body.at_css("form")

          assert fv5007
          fv5006 =
            fv5007.css("input[name]").to_h { |fv5008|
              [fv5008["name"], fv5008["value"]]
            }
          post(
            fv5007["action"],
            params: fv5006,
            headers: {
              "Host" => @base_host,
              "Origin" => "https://#{@base_host}",
              "Sec-Fetch-Site" => "same-origin",
            },
          )
        end
      end

      assert_response :see_other
      gateway = URI.parse(response.location)

      assert_equal "jump.umaxica.net", gateway.host
      payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)

      assert_equal "https://auth.umaxica.app/settings/google", payload.fetch("url").split("?").first
    end
  end

  test "an apple link completion is sent back to the apple settings page" do
    travel_to(@now) do
      begin
        fv5005 = issue_link_result(provider: "apple")
        fv5004 = "apple"
        fv5003 = SocialCeremonyResultAdapter.new.issue!(
          token: fv5005,
          expires_at: @now + 1.minute,
          now: @now,
        )
        host!(@base_host)
        https!
        get(
          base_app_social_authentication_completion_path(
            id: fv5004, result_ref: fv5003, ri: "jp",
          ),
        )

        assert_response :success

        fv5001 = response.parsed_body.at_css("form")

        assert fv5001
        fv5000 =
          fv5001.css("input[name]").to_h { |fv5002|
            [fv5002["name"], fv5002["value"]]
          }
        post(
          fv5001["action"],
          params: fv5000,
          headers: {
            "Host" => @base_host,
            "Origin" => "https://#{@base_host}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
      end

      assert_response :see_other
      gateway = URI.parse(response.location)

      assert_equal "jump.umaxica.net", gateway.host
      payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)

      assert_equal "https://auth.umaxica.app/settings/apple", payload.fetch("url").split("?").first
    end
  end

  private

  def issue_link_result(provider: "google")
    grant = IdentitySocialCeremonyGrantIssuer.issue!(
      surface: "app", actor_ref: @client.public_id, session_ref: @session_ref,
      operation: "link", provider: provider, now: @now,
    )
    callback_result = ExternalAuthentication::CallbackResult.verified(
      principal: ExternalAuthentication::VerifiedPrincipal.new(
        provider: provider,
        subject: @uid,
        issuer: ((provider == "apple") ? "https://appleid.apple.com" : "https://accounts.google.com"),
        audience: "#{provider}-client-id",
        verified_at: @now,
        verification_authority: "test-provider-contract",
      ),
      credential_candidate: nil,
    )
    IdentitySocialCeremonyResultIssuer.issue!(
      grant_token: grant.grant, callback_result: callback_result, surface: "app",
      actor_ref: @client.public_id, session_ref: @session_ref, operation: "link", now: @now,
    )
  end

  def issue_login_result
    grant = IdentitySocialCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "login",
      provider: "google",
      now: @now,
    )
    callback_result = ExternalAuthentication::CallbackResult.verified(
      principal: ExternalAuthentication::VerifiedPrincipal.new(
        provider: "google",
        subject: @uid,
        issuer: "https://accounts.google.com",
        audience: "google-client-id",
        verified_at: @now,
        verification_authority: "test-provider-contract",
      ),
      credential_candidate: nil,
    )
    IdentitySocialCeremonyResultIssuer.issue!(
      grant_token: grant.grant,
      callback_result: callback_result,
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "login",
      now: @now,
    )
  end
end
