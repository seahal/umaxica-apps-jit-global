# typed: false
# frozen_string_literal: true

require "test_helper"

class Palm::App::Sign::Out::CompletionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_PALM_SERVICE_URL")
    host! @host
    https!
  end

  test "a client's Palm session can complete RP cleanup through its protected completion form" do
    previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    client = clients(:one)
    oidc_client = OidcClientRegistry.find!("palm-app-jp")
    root_token = ClientToken.create!(user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    rp_session = OpAppGrant.create!(
      client_token: root_token,
      oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(
      origin_surface: "palm",
      surface: "app",
    )
    origin_intent_proof = SecureRandom.random_bytes(32)
    issue_result = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "palm",
      workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
      initiating_client_id: oidc_client.client_id,
      completion_url: completion_url,
      actor_ref: client.public_id,
      session_ref: rp_session.public_id,
      **AcmeLogoutTransactionCoordinator.browser_rp_binding_for(
        session_record: rp_session,
        resource_type: "client",
        origin_intent_digest: Digest::SHA256.digest(origin_intent_proof),
      ),
      surface: "app",
    )

    assert_predicate issue_result, :success?
    transaction = issue_result.transaction
    AcmeLogoutTransactionCoordinator.advance!(
      logout_challenge: transaction.logout_challenge,
      step: AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
    )
    AcmeLogoutTransactionCoordinator.advance!(
      logout_challenge: transaction.logout_challenge,
      step: AcmeLogoutTransaction::STEP_AUTHORITY_CLEANUP_ISSUED,
    )

    completion_path = palm_app_sign_out_completion_path(logout_challenge: transaction.logout_challenge)

    get(completion_path)
    follow_redirect! if response.redirect?

    install_browser_rp_logout_proof!(transaction, origin_intent_proof)
    get(completion_path)
    follow_redirect! if response.redirect?

    assert_response :success
    form = css_select("form").first

    assert_equal "/sign/out/completion", URI.parse(form["action"]).path
    assert_empty css_select('form input[name="_method"][value="delete"]')
    params =
      form.css("input").each_with_object({}) do |input, values|
        values[input["name"]] = input["value"] if input["name"].present?
      end

    assert_equal Base64.strict_encode64(origin_intent_proof), params.fetch("logout_intent_proof")

    post(
      form["action"],
      params: params,
      headers: {
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_response :see_other, response.body
    assert_equal URI.parse(completion_url).host, URI.parse(response.location).host
    assert_equal "/sign/out/completion", URI.parse(response.location).path
    assert_predicate transaction.reload, :finalized?
    assert_predicate rp_session.reload, :revoked?
    assert_predicate root_token.reload, :currently_usable?
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery_protection
  end

  private

  def install_browser_rp_logout_proof!(transaction, raw_proof)
    install_browser_rp_logout_proof_in_session!(self, transaction, raw_proof)
  end

  def install_browser_rp_logout_proof_in_session!(browser, transaction, raw_proof)
    session_key = Rails.application.config.session_options.fetch(:key)
    cookie_jar = ActionDispatch::Cookies::CookieJar.build(browser.request, browser.request.cookies)
    session_state = { "session_id" => SecureRandom.hex(16) }.merge(browser.request.session.to_hash.stringify_keys)
    session_state[AcmeLogoutTransactionable::BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY.to_s] = {
      transaction.logout_challenge => {
        "proof" => Base64.strict_encode64(raw_proof),
        "client_id" => transaction.initiating_client_id,
        "session_ref" => transaction.session_ref,
        "parent_session_ref" => transaction.parent_session_ref,
        "expires_at" => transaction.expires_at.iso8601(6),
      },
    }
    cookie_jar.encrypted[session_key] = { value: session_state }
    encoded_session = cookie_jar[session_key]
    browser.cookies.delete(session_key)
    store_raw_cookies(
      browser.cookies,
      "#{session_key}=#{Rack::Utils.escape(encoded_session)}",
      URI.parse("https://#{@host}/"),
    )
  end
end
