# typed: false
# frozen_string_literal: true

require "test_helper"

class Tech::Org::Sign::Out::CompletionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_TECH_STAFF_URL")
    host! @host
    https!
  end

  test "an operator without tech access can complete its RP cleanup challenge" do
    previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    operator = operators(:one)
    client = OidcClientRegistry.find!("tech-org-ww")
    root_token = OperatorToken.create!(staff: operator)
    rp_session = OpOrgGrant.create!(
      operator_token: root_token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(
      origin_surface: "tech",
      surface: "org",
      ri: "jp",
    )
    origin_intent_proof = SecureRandom.random_bytes(32)
    issue_result = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: "tech",
      workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
      initiating_client_id: client.client_id,
      completion_url: completion_url,
      actor_ref: operator.public_id,
      session_ref: rp_session.public_id,
      **AcmeLogoutTransactionCoordinator.browser_rp_binding_for(
        session_record: rp_session,
        resource_type: "operator",
        origin_intent_digest: Digest::SHA256.digest(origin_intent_proof),
      ),
      surface: "org",
      ri: "jp",
    )

    assert_predicate issue_result, :success?
    transaction = issue_result.transaction

    completion_path = tech_org_sign_out_completion_path(
      logout_challenge: transaction.logout_challenge,
      ri: "jp",
    )

    get(completion_path)

    assert_response :not_found

    AcmeLogoutTransactionCoordinator.advance!(
      logout_challenge: transaction.logout_challenge,
      step: AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
    )
    AcmeLogoutTransactionCoordinator.advance!(
      logout_challenge: transaction.logout_challenge,
      step: AcmeLogoutTransaction::STEP_AUTHORITY_CLEANUP_ISSUED,
    )

    install_browser_rp_logout_proof!(transaction, origin_intent_proof)
    get(completion_path)

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
    session_key = Rails.application.config.session_options.fetch(:key)
    cookie_jar = ActionDispatch::Cookies::CookieJar.build(request, request.cookies)
    session_state = { "session_id" => SecureRandom.hex(16) }.merge(request.session.to_hash.stringify_keys)
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
    cookies.delete(session_key)
    store_raw_cookies(
      cookies,
      "#{session_key}=#{Rack::Utils.escape(encoded_session)}",
      URI.parse("https://#{@host}/"),
    )
  end
end
