# frozen_string_literal: true

require "test_helper"

# AT-011 (S4): the sign-out contract of AT-001 to AT-009 for every registered first-party Browser RP,
# through the realm's own Base authority: the global sign-out, the IdP-session-absent error, a
# different account at the IdP, a resubmitted confirmation and a failed progress write after the
# parent COMMIT. Transactions are issued exactly as the origin issues them; the confirmation is the
# real Base POST with a real IdP access credential.
class OidcRpLogoutRegisteredRpMatrixTest < ActionDispatch::IntegrationTest
  REALMS = {
    "client" => { base_env: "PUBLIC_BASE_SERVICE_URL", path: :base_app_oidc_logout_path },
    "visitor" => { base_env: "PUBLIC_BASE_CORPORATE_URL", path: :base_com_oidc_logout_path },
    "operator" => { base_env: "PUBLIC_BASE_STAFF_URL", path: :base_org_oidc_logout_path },
  }.freeze

  setup { https! }

  AuthBoundaryAuthorityMap::FIRST_PARTY_RP_CLIENT_IDS.each do |client_id|
    test "#{client_id}: a confirmed global sign-out revokes the parent and every RP row" do
      setup_rp(client_id)
      sibling = create_rp_session(@root_token, sibling_client_id)

      confirm(authority_headers(@actor, @root_token))

      assert_response :see_other
      assert_equal URI.parse(@transaction.completion_url).host, URI.parse(response.location).host
      assert_not_predicate @root_token.reload, :currently_usable?
      assert_predicate @rp_session.reload, :revoked?
      assert_predicate sibling.reload, :revoked? if sibling
    end

    test "#{client_id}: without an IdP session nothing is revoked and nothing redirects" do
      setup_rp(client_id)

      confirm({})

      assert_idp_session_error
      assert_untouched
    end

    test "#{client_id}: a resubmitted confirmation changes nothing more and touches no other parent" do
      setup_rp(client_id)
      other_root = create_root(@actor)
      headers = authority_headers(@actor, @root_token)
      confirm(headers)

      assert_response :see_other
      steps = @transaction.reload.completed_steps

      confirm(headers)

      assert_not_equal 500, response.status
      assert_equal steps, @transaction.reload.completed_steps
      assert_predicate other_root.reload, :currently_usable?
    end

    test "#{client_id}: a failed progress write after the parent COMMIT shows the global result" do
      setup_rp(client_id)
      failed = AcmeLogoutTransactionCoordinator::Result.new(
        transaction: nil, status: :rejected, error: "invalid_request", error_description: "progress write failed",
      )

      AcmeLogoutTransactionCoordinator.stub(:advance!, ->(**) { failed }) do
        confirm(authority_headers(@actor, @root_token))
      end

      assert_response :ok
      assert_includes response.body, I18n.t("sign.shared.sign_out.cleanup_incomplete_description")
      assert_not_predicate @root_token.reload, :currently_usable?
    end

    test "#{client_id}: the cleanup-incomplete page after the parent COMMIT clears Inertia history" do
      setup_rp(client_id)
      failed = AcmeLogoutTransactionCoordinator::Result.new(
        transaction: nil, status: :rejected, error: "invalid_request", error_description: "progress write failed",
      )

      AcmeLogoutTransactionCoordinator.stub(:advance!, ->(**) { failed }) do
        confirm(authority_headers(@actor, @root_token))
      end

      assert_response :ok
      assert_not_predicate @root_token.reload, :currently_usable?
      assert inertia_page.fetch("clearHistory")
    end

    test "#{client_id}: the indeterminate page for an unknown COMMIT outcome clears Inertia history" do
      setup_rp(client_id)
      raise_unknown = ->(**) { raise AuthenticationLogoutCurrentSession::CommitOutcomeUnknown }

      AuthenticationLogoutCurrentSession.stub(:call, raise_unknown) do
        confirm(authority_headers(@actor, @root_token))
      end

      assert_response :service_unavailable
      assert_includes response.body, I18n.t("sign.shared.sign_out.indeterminate_title")
      assert inertia_page.fetch("clearHistory")
    end

    test "#{client_id}: a different account at the IdP revokes neither account's parent" do
      setup_rp(client_id)
      other_actor = second_actor
      other_root = create_root(other_actor)

      confirm(authority_headers(other_actor, other_root))

      assert_idp_session_error
      assert_untouched
      assert_predicate other_root.reload, :currently_usable?
    end
  end

  private

  def setup_rp(client_id)
    @face = AuthBoundaryAuthorityMap.rp_faces.fetch(client_id)
    @resource_type = @face.fetch(:actor)
    @realm = REALMS.fetch(@resource_type)
    @client = OidcClientRegistry.find!(client_id)
    @actor = first_actor
    # Operators allow two concurrent sessions; start every case from no live session.
    AuthenticationSessionRevoker.tokens_for(@actor).find_each(&:revoke!)
    @root_token = create_root(@actor)
    @rp_session = create_rp_session(@root_token, client_id)
    proof = SecureRandom.random_bytes(32)
    result = AcmeLogoutTransactionCoordinator.issue!(
      origin_surface: @face.fetch(:surface),
      workflow: AcmeLogoutTransaction::BROWSER_RP_WORKFLOW,
      initiating_client_id: @client.client_id,
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: @face.fetch(:surface), surface: @face.fetch(:face), ri: "jp",
      ),
      actor_ref: @actor.public_id,
      session_ref: @rp_session.public_id,
      **AcmeLogoutTransactionCoordinator.browser_rp_binding_for(
        session_record: @rp_session, resource_type: @resource_type, origin_intent_digest: Digest::SHA256.digest(proof),
      ),
      surface: @face.fetch(:face),
      ri: "jp",
    )

    assert_predicate result, :success?
    @transaction = result.transaction
  end

  def first_actor
    { "client" => clients(:one), "visitor" => visitors(:reserved_visitor), "operator" => operators(:one) }
      .fetch(@resource_type)
  end

  def second_actor
    # The com realm has a single Visitor fixture, so its second account is created here.
    { "client" => -> { clients(:two) }, "visitor" => -> { Visitor.create! }, "operator" => -> { operators(:two) } }
      .fetch(@resource_type).call
  end

  def create_root(actor)
    case @resource_type
    when "client"
      ClientToken.create!(
        user: actor, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
      )
    when "visitor"
      VisitorToken.create!(
        visitor: actor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
        visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      )
    when "operator"
      OperatorToken.create!(
        staff: actor, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
        staff_token_status_id: OperatorTokenStatus::ACTIVE,
      )
    end
  end

  def create_rp_session(root_token, client_id)
    return if client_id.nil?

    attributes = {
      oidc_client_id: OidcClientRegistry.find!(client_id).client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    }
    case @resource_type
    when "client" then OpAppGrant.create!(client_token: root_token, **attributes)
    when "visitor" then OpComGrant.create!(visitor_token: root_token, **attributes)
    when "operator" then OpOrgGrant.create!(operator_token: root_token, **attributes)
    end
  end

  def sibling_client_id
    (AuthBoundaryAuthorityMap::FIRST_PARTY_RP_CLIENT_IDS - [@client.client_id]).find do |client_id|
      AuthBoundaryAuthorityMap.rp_faces.fetch(client_id).fetch(:actor) == @resource_type
    end
  end

  def authority_headers(actor, root_token)
    base_host = ENV.fetch(@realm.fetch(:base_env))
    device_session = root_token.device_session_record
    access_token = AuthenticationToken.encode(
      actor,
      host: base_host,
      session_public_id: device_session.public_id,
      oidc_sid: device_session.public_id,
      oidc_jti: root_token.oidc_jti,
      resource_type: @resource_type,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(@resource_type),
      authentication_context: root_token.authentication_context_value.to_s,
    )
    cookie = "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(access_token)}"
    { "Cookie" => cookie, "HTTP_COOKIE" => cookie }
  end

  def confirm(headers)
    host!(ENV.fetch(@realm.fetch(:base_env)))
    origin = URI.parse(@transaction.completion_url)
    post(
      public_send(@realm.fetch(:path), logout_challenge: @transaction.logout_challenge, ri: "jp"),
      headers: headers.merge("Origin" => "#{origin.scheme}://#{origin.host}", "Sec-Fetch-Site" => "same-site"),
    )
  end

  def assert_idp_session_error
    assert_response :bad_request
    assert_equal I18n.t("sign.shared.sign_out.idp_session_error"), response.body
    assert_nil response.location
    assert_includes response.headers.fetch("Cache-Control").downcase, "no-store"
  end

  def assert_untouched
    assert_predicate @root_token.reload, :currently_usable?
    assert_predicate @rp_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED, @transaction.reload.expected_step
  end
end
