# typed: false
# frozen_string_literal: true

require "test_helper"

# A social login for an account that has not finished sign-up must not sign the
# person in: the completion endpoint hands it to the sign-up guard instead, after
# binding a pending sign-up ticket to the identity. That branch of
# Base::App::Social::Authentication::CompletionsController had no test, so a
# regression would have signed a half-registered account straight in.
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

  test "a login for an account without a birthdate is handed to the sign-up guard" do
    travel_to(@now) do
      result_token = issue_login_result

      assert_difference -> { ClientSignUpFlow.where(principal_id: @client.id).count }, 1 do
      complete_staged_result!(result_token: result_token, provider: "google")
      end

      assert_response :redirect
      gateway = URI.parse(response.location)

      assert_equal "jump.umaxica.net", gateway.host
      payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)

      assert_equal "https://auth.umaxica.app/sign/up/guard/google", payload.fetch("url").split("?").first

      cycle = ClientSignUpFlow.where(principal_id: @client.id).recent_first.first

      assert_equal "google", cycle.social_provider
      assert_equal "social_identity", cycle.pending_contact_type
    end
  end

  # This endpoint is the login-only completion path. A link completion posted here
  # is refused before any trust decision, and sent back to the provider's settings
  # page instead of being processed.
  test "a link completion posted to the login endpoint is sent back to settings" do
    travel_to(@now) do
      assert_no_difference -> { ClientSignUpFlow.where(principal_id: @client.id).count } do
        complete_staged_result!(result_token: issue_link_result, provider: "google")
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
      complete_staged_result!(result_token: issue_link_result(provider: "apple"), provider: "apple")

      assert_response :see_other
      gateway = URI.parse(response.location)

      assert_equal "jump.umaxica.net", gateway.host
      payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)

      assert_equal "https://auth.umaxica.app/settings/apple", payload.fetch("url").split("?").first
    end
  end

  private

  def complete_staged_result!(result_token:, provider:)
    reference = Valkey::AuthState::SocialCeremonyResultStore.new.issue!(
      token: result_token,
      expires_at: @now + 1.minute,
      now: @now,
    )
    host!(@base_host)
    https!
    get base_app_social_authentication_completion_path(
      id: provider, result_ref: reference, ri: "jp",
    )
    assert_response :success

    form = response.parsed_body.at_css("form")
    assert form
    params = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    post form["action"],
         params: params,
         headers: {
           "Host" => @base_host,
           "Origin" => "https://#{@base_host}",
           "Sec-Fetch-Site" => "same-origin",
         }
  end

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
