# frozen_string_literal: true

require "test_helper"

class OidcRpCompletionMatrixTest < ActionDispatch::IntegrationTest
  test "every first-party Browser RP reads and completes its own logout challenge" do # rubocop:disable Minitest/MultipleAssertions -- Each registered client exercises the same ordered refusal and completion contract.
    previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    client_actor = clients(:one)
    client_root_token = ClientToken.create!(
      authentication_epoch: 0,
      user: client_actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    visitor_actor = visitors(:reserved_visitor)
    visitor_root_token = VisitorToken.create!(
      authentication_epoch: 0,
      visitor: visitor_actor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
    )
    operator_actor = operators(:one)
    operator_root_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: operator_actor,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
    )
    matrix = []

    AuthBoundaryAuthorityMap::FIRST_PARTY_RP_CLIENT_IDS.each do |client_id|
      face = AuthBoundaryAuthorityMap.rp_faces.fetch(client_id)
      actor = nil
      root_token = nil
      rp_session = nil
      client = OidcClientRegistry.find!(client_id)

      case face.fetch(:actor)
      when "client"
        actor = client_actor
        root_token = client_root_token
        rp_session = OpAppGrant.create!(
          authentication_epoch: 0,
          client_token: root_token,
          oidc_client_id: client.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: 1.minute.ago,
          refresh_token_expires_at: 10.minutes.from_now,
        )
      when "visitor"
        actor = visitor_actor
        root_token = visitor_root_token
        rp_session = OpComGrant.create!(
          authentication_epoch: 0,
          visitor_token: root_token,
          oidc_client_id: client.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: 1.minute.ago,
          refresh_token_expires_at: 10.minutes.from_now,
        )
      when "operator"
        actor = operator_actor
        root_token = operator_root_token
        rp_session = OpOrgGrant.create!(
          authentication_epoch: 0,
          operator_token: root_token,
          oidc_client_id: client.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: 1.minute.ago,
          refresh_token_expires_at: 10.minutes.from_now,
        )
      else
        flunk("#{client_id} has an unsupported RP actor type")
      end

      completion_url = AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: face.fetch(:surface),
        surface: face.fetch(:face),
        ri: "jp",
      )
      origin_intent_proof = SecureRandom.random_bytes(32)
      resource_type = { "client" => "client", "visitor" => "visitor", "operator" => "operator" }.fetch(
        face.fetch(:actor),
      )
      issue_result = AcmeLogoutTransactionCoordinator.issue!(
        origin_surface: face.fetch(:surface),
        workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
        initiating_client_id: client.client_id,
        completion_url: completion_url,
        actor_ref: actor.public_id,
        session_ref: rp_session.public_id,
        **AcmeLogoutTransactionCoordinator.browser_rp_binding_for(
          session_record: rp_session,
          resource_type: resource_type,
          origin_intent_digest: Digest::SHA256.digest(origin_intent_proof),
        ),
        surface: face.fetch(:face),
        ri: "jp",
      )

      assert_predicate issue_result, :success?, client_id
      matrix << {
        client_id: client_id,
        face: face,
        actor: actor,
        root_token: root_token,
        rp_session: rp_session,
        completion_url: completion_url,
        origin_intent_proof: origin_intent_proof,
        transaction: issue_result.transaction,
      }
    end

    [client_root_token, visitor_root_token, operator_root_token].each do |root_token|
      revocation = RpSessionRevoker.call(scope: :browser_session, record: root_token, status: "success")

      assert_predicate revocation, :success?
      assert_not_predicate root_token.reload, :currently_usable?
    end

    matrix.each do |entry|
      client_id = entry.fetch(:client_id)
      rp_session = entry.fetch(:rp_session)
      root_token = entry.fetch(:root_token)
      transaction = entry.fetch(:transaction)
      completion_url = entry.fetch(:completion_url)
      origin_intent_proof = entry.fetch(:origin_intent_proof)
      AcmeLogoutTransactionCoordinator.advance!(
        logout_challenge: transaction.logout_challenge,
        step: AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
      )
      AcmeLogoutTransactionCoordinator.advance!(
        logout_challenge: transaction.logout_challenge,
        step: AcmeLogoutTransaction::STEP_AUTHORITY_CLEANUP_ISSUED,
      )

      completion_uri = URI.parse(completion_url)
      completion_query = Rack::Utils.parse_nested_query(completion_uri.query.to_s)
      completion_query["logout_challenge"] = transaction.logout_challenge
      completion_uri.query = completion_query.to_query
      browser = open_session
      browser.host!(completion_uri.host)
      browser.https! if completion_uri.scheme == "https"

      transaction_before_get = transaction.reload.attributes
      browser.get(completion_uri.request_uri)

      assert_equal 200, browser.response.status, "#{client_id} challenge GET"
      assert_equal transaction_before_get, transaction.reload.attributes,
                   "#{client_id} GET preserves all transaction fields"
      unbound_page = browser.response.parsed_body
      csrf = unbound_page.at_css('meta[name="csrf-token"]')&.[]("content") ||
        unbound_page.at_css('input[name="authenticity_token"]')&.[]("value")

      assert_predicate csrf, :present?, "#{client_id} unbound form CSRF"
      step_before_unbound_post = transaction.reload.expected_step
      browser.post(
        completion_uri.request_uri,
        params: { logout_challenge: transaction.logout_challenge, ri: "jp", authenticity_token: csrf },
        headers: {
          "Origin" => "#{completion_uri.scheme}://#{completion_uri.host}",
          "Sec-Fetch-Site" => "same-origin",
          "X-CSRF-Token" => csrf,
        },
      )

      assert_includes [403, 422], browser.response.status, "#{client_id} unbound continuation refusal"
      assert_includes browser.response.headers["Cache-Control"].split(",").map(&:strip), "no-store",
                      "#{client_id} unbound refusal cache policy"
      assert_equal step_before_unbound_post, transaction.reload.expected_step,
                   "#{client_id} unbound POST preserves transaction"
      assert_not_predicate transaction, :finalized?, "#{client_id} unbound POST cannot complete"
      install_browser_rp_logout_proof!(browser, transaction, origin_intent_proof)
      transaction_before_bound_get = transaction.reload.attributes
      browser.get(completion_uri.request_uri)

      assert_equal 200, browser.response.status, "#{client_id} challenge GET with bound proof"
      assert_equal transaction_before_bound_get, transaction.reload.attributes,
                   "#{client_id} bound GET preserves all transaction fields"
      page = browser.response.parsed_body
      html_form = page.at_css("form")
      if html_form
        form_action = URI.join(completion_url, html_form["action"])
        form_fields =
          html_form.css("input[name]").each_with_object({}) do |input, fields|
            fields[input["name"]] = input["value"]
          end

        assert_empty html_form.css('input[name="_method"][value="delete"]'),
                     "#{client_id} challenge DELETE control"
      else
        inertia_script = page.at_css('script[type="application/json"][data-page]')

        assert inertia_script, "#{client_id} Inertia page"

        inertia_page = JSON.parse(inertia_script.text)
        form_props = inertia_page.dig("props", "form")

        assert form_props, "#{client_id} Inertia completion form"

        form_action = URI.join(completion_url, form_props.fetch("action"))
        form_fields = form_props.slice("logout_challenge", "ri", "logout_intent_proof").compact
      end

      assert_equal completion_uri.host, form_action.host, "#{client_id} form host"
      assert_equal "/sign/out/completion", form_action.path, "#{client_id} form path"
      csrf_meta = page.at_css('meta[name="csrf-token"]')
      csrf_token = form_fields["authenticity_token"].presence || csrf_meta&.[]("content")

      assert_predicate csrf_token, :present?, "#{client_id} completion CSRF token"
      form_fields["logout_challenge"] = transaction.logout_challenge
      form_fields["ri"] = "jp"
      form_fields["logout_intent_proof"] = Base64.strict_encode64(origin_intent_proof)
      form_fields["authenticity_token"] = csrf_token

      assert_equal AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED, transaction.reload.expected_step,
                   "#{client_id} GET transaction state"
      assert_predicate rp_session.reload, :revoked?, "#{client_id} GET RP session state"
      assert_not_predicate root_token.reload, :currently_usable?, "#{client_id} GET root token state"

      wrong_proof = origin_intent_proof.dup
      wrong_proof.setbyte(0, wrong_proof.getbyte(0) ^ 1)
      browser.post(
        form_action.request_uri,
        params: form_fields.merge("logout_intent_proof" => Base64.strict_encode64(wrong_proof)),
        headers: {
          "Origin" => "#{form_action.scheme}://#{form_action.host}",
          "Sec-Fetch-Site" => "same-origin",
          "X-CSRF-Token" => csrf_token,
        },
      )

      assert_equal 422, browser.response.status, "#{client_id} mismatched proof refusal"
      assert_includes browser.response.headers["Cache-Control"].split(",").map(&:strip), "no-store",
                      "#{client_id} proof refusal cache policy"
      assert_equal AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED, transaction.reload.expected_step,
                   "#{client_id} mismatched proof preserves transaction"
      assert_not_predicate transaction, :finalized?, "#{client_id} mismatched proof cannot complete"

      browser.post(
        form_action.request_uri,
        params: form_fields.merge("authenticity_token" => "invalid-token"),
        headers: {
          "Origin" => "#{form_action.scheme}://#{form_action.host}",
          "Sec-Fetch-Site" => "same-origin",
          "X-CSRF-Token" => "invalid-token",
        },
      )

      assert_equal 422, browser.response.status, "#{client_id} invalid CSRF continuation refusal"
      assert_equal AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED, transaction.reload.expected_step,
                   "#{client_id} invalid CSRF preserves transaction"

      browser.post(
        form_action.request_uri,
        params: form_fields.except("authenticity_token"),
        headers: {
          "Origin" => "#{form_action.scheme}://#{form_action.host}",
          "Sec-Fetch-Site" => "same-origin",
        },
      )

      assert_equal 422, browser.response.status, "#{client_id} missing CSRF continuation refusal"
      assert_equal AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED, transaction.reload.expected_step,
                   "#{client_id} missing CSRF preserves transaction"

      browser.post(
        form_action.request_uri, params: form_fields,
                                 headers: {
                                   "Origin" => "https://foreign.invalid",
                                   "Sec-Fetch-Site" => "same-origin",
                                   "X-CSRF-Token" => csrf_token,
                                 },
      )

      assert_equal 422, browser.response.status, "#{client_id} foreign Origin continuation refusal"
      assert_equal AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED, transaction.reload.expected_step,
                   "#{client_id} foreign Origin preserves transaction"

      browser.post(
        form_action.request_uri,
        params: form_fields.merge("authenticity_token" => "invalid-token"),
        headers: {
          "Origin" => "#{form_action.scheme}://#{form_action.host}",
          "Sec-Fetch-Site" => "same-origin",
          "X-CSRF-Token" => "invalid-token",
        },
        as: :json,
      )

      assert_equal 403, browser.response.status, "#{client_id} JSON invalid token refusal"
      assert_equal AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED, transaction.reload.expected_step,
                   "#{client_id} JSON invalid token preserves transaction"

      browser.post(
        form_action.request_uri,
        params: form_fields.merge("authenticity_token" => "invalid-token"),
        headers: {
          "Origin" => "#{form_action.scheme}://#{form_action.host}",
          "X-CSRF-Token" => "invalid-token",
        },
        as: :json,
      )

      assert_equal 403, browser.response.status, "#{client_id} JSON refusal without Fetch Metadata"
      assert_equal AcmeLogoutTransaction::STEP_ORIGIN_CLEANUP_ISSUED, transaction.reload.expected_step,
                   "#{client_id} absent Fetch Metadata refusal preserves transaction"

      browser.post(
        form_action.request_uri, params: form_fields, headers: {
          "Origin" => "#{form_action.scheme}://#{form_action.host}",
          "X-CSRF-Token" => csrf_token,
        },
      )

      assert_equal 303, browser.response.status, "#{client_id} challenge POST"
      assert_equal completion_url, browser.response.location, "#{client_id} completion redirect"
      assert_predicate transaction.reload, :finalized?, "#{client_id} transaction state"
      assert_predicate rp_session.reload, :revoked?, "#{client_id} origin RP session state"
      assert_not_predicate root_token.reload, :currently_usable?, "#{client_id} parent token state"

      final_uri = URI.parse(completion_url)
      browser.get(final_uri.request_uri)

      assert_includes [200, 303], browser.response.status, "#{client_id} final completion GET"
      if browser.response.status == 303
        completion_redirect = URI.parse(browser.response.location)

        assert_equal final_uri.host, completion_redirect.host, "#{client_id} final redirect host"
      end

      browser.get(final_uri.request_uri)

      assert_equal 404, browser.response.status, "#{client_id} consumed completion notice"
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous_forgery_protection
  end

  private

  def install_browser_rp_logout_proof!(browser, transaction, raw_proof)
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
      URI.parse("#{completion_uri_scheme(browser)}://#{browser.request.host}/"),
    )
  end

  def completion_uri_scheme(browser)
    browser.request.ssl? ? "https" : "http"
  end
end
