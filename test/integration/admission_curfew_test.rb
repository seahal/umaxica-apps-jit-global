# typed: false
# frozen_string_literal: true

require "test_helper"

# WU-06 (REQ-CURFEW 3, D-160): an admitted Sign-in path request is allowed before the Binding's
# curfew and refused at it and after it. The owner's own browser leaves through the Cancel exit and
# the RP receives access_denied with its unchanged state; a browser without the ceremony gets the
# uniform error. Boundaries are set relative to the Binding's own OP database clock.
class AdmissionCurfewTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    ri = "jp"
    @base_browser = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/sign", params: { ri: ri, pt: "/dashboard?ri=#{ri}" })
    form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    @base_browser.post(
      form["action"], params: fields, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )
    current_browser = @base_browser
    current_host = base_host
    jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

    12.times do
      break unless current_browser.response.redirect?

      target = URI.parse(current_browser.response.location.to_s)
      target = URI.parse("https://#{current_host}#{target}") if target.host.blank?
      target = URI.parse(jump_rt_url_from_location_for_test(target.to_s)) if target.host == jump_host

      case target.host
      when base_host
        @base_browser.host!(base_host)
        @base_browser.https!
        @base_browser.get(target.request_uri, headers: navigation_headers(site: "cross-site"))
        current_browser = @base_browser
        current_host = base_host
      when visa_host_for_test_base_host(base_host)
        @base_browser.host!(target.host)
        @base_browser.https!
        @base_browser.get(target.request_uri, headers: navigation_headers(site: "cross-site"))
        current_browser = @base_browser
        current_host = target.host
      when auth_host
        host!(auth_host)
        https!
        get(target.request_uri, headers: navigation_headers(site: "cross-site"))
        current_browser = self
        current_host = auth_host
      else
        raise RuntimeError, "Unexpected curfew bootstrap host: #{target.host.inspect}"
      end
    end

    raise RuntimeError, "Curfew setup did not reach Auth" unless current_browser.equal?(self)
    raise RuntimeError, "Curfew setup did not render Auth entry" unless response.successful?

    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @binding = ClientAuthAdmissionBinding.where.not(admitted_auth_ceremony_session_id: nil).order(:id).last
    @transaction = ClientOidcAuthorizationTransaction.find(@binding.authorization_transaction_id)
  end

  test "A06-1: an admitted page one second before the curfew is served" do
    decision_time = ClientAuthAdmissionBinding.database_now
    @binding.update_columns(curfew_at: decision_time + 1.second)
    ClientAuthAdmissionBinding.stub(:database_now, decision_time) do
      get "/sign/in", params: { ri: "jp" }
    end

    assert_response :success
  end

  test "A06-4: APP, COM and ORG ceremony parents share the exact stored curfew" do
    cases = [
      ["app", @binding.reload, @transaction.reload, ClientAuthCeremonySession],
    ]

    [
      ["com", "core-com-jp", "visitor", ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
       VisitorAuthAdmissionBinding, VisitorAuthCeremonySession,],
      ["org", "core-org-jp", "operator", ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
       OperatorAuthAdmissionBinding, OperatorAuthCeremonySession,],
    ].each do |surface, client_id, realm, auth_host, binding_class, ceremony_class|
      client = OidcClientRegistry.find!(client_id)
      transaction = OidcAuthorizationTransactionCoordinator.issue!(
        surface:, intent: "sign_in", params: {
          client_id:,
          response_type: "code",
          scope: "openid profile",
          redirect_uri: client.redirect_uris_by_realm.fetch(realm).first,
          state: SecureRandom.urlsafe_base64(24),
          nonce: SecureRandom.urlsafe_base64(24),
          code_challenge: SecureRandom.urlsafe_base64(32, padding: false),
          code_challenge_method: "S256",
        },
      ).transaction
      issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction:, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      binding = binding_class.find_by!(entry_ref: issuance.reference)
      browser = open_session
      browser.host!(auth_host)
      browser.https!
      entry_path = "/sign/in?#{Rack::Utils.build_query(entry_ref: issuance.reference, ri: "jp")}"
      browser.get(entry_path, headers: navigation_headers(site: "cross-site"))

      assert_equal 303, browser.response.status
      browser.get(browser.response.location, headers: navigation_headers(site: "cross-site"))

      assert_equal 303, browser.response.status
      binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
      browser.get(entry_path, headers: navigation_headers(site: "cross-site"))

      assert_equal 303, browser.response.status
      cases << [surface, binding.reload, transaction.reload, ceremony_class]
    end

    cases.each do |surface, binding, transaction, ceremony_class|
      curfew_at = binding.curfew_at
      ceremony = ceremony_class.find(binding.admitted_auth_ceremony_session_id)
      at_30_01 = curfew_at + 1.second

      # D-36 gives the Binding's 60-second expiry ownership of redemption only.
      assert_operator transaction.expires_at, :>=, curfew_at, surface
      assert_equal curfew_at, ceremony.expires_at, "#{surface} ceremony ends at the stored curfew"
      assert ceremony.active?(now: curfew_at - Rational(1, 1_000_000)),
             "#{surface} ceremony is active 1µs before curfew"
      assert_not ceremony.active?(now: curfew_at), "#{surface} ceremony expires at curfew"
      assert_not ceremony.active?(now: curfew_at + Rational(1, 1_000_000)),
                 "#{surface} ceremony stays expired after curfew"
      assert_operator at_30_01, :>, curfew_at
      assert transaction.class.exists?(id: transaction.id),
             "#{surface} OIDC transaction row remains present at 30:01"
      assert_not transaction.class.purgeable_at(at_30_01).exists?(id: transaction.id),
                 "#{surface} OIDC transaction is outside the configured retention window at 30:01"
      assert_operator transaction.login_challenge_expires_at, :>=, curfew_at, surface
    end
  end

  test "A07-2: a definitive curfew refusal clears only this browser's sign-in continuity" do
    move_curfew!(-1.second)
    continuity = {
      app_sign_in_flow_locator: { "public_id" => "signin-flow", "nonce" => "signin-nonce" },
      app_sign_up_flow_locator: { "public_id" => "signup-flow", "nonce" => "signup-nonce" },
      auth_app_up_sequence_id: "signup-sequence",
      social_auth_intent: "signup",
      social_auth_flow_id: "social-flow",
      social_auth_provider: "google",
      social_auth_state: "social-state",
      social_auth_state_started_at: 1_761_408_000,
      social_auth_state_provider: "google",
    }
    continuity.each { |key, value| session[key] = value }
    sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"

    assert_predicate cookies[sid_cookie], :present?

    get "/sign/in", params: { ri: "jp" }

    assert_response :see_other
    continuity.each { |key, _value| assert_nil session[key], "#{key} is cleared after a definitive refusal" }
    assert_empty cookies[sid_cookie]
  end

  [0, -1].each do |offset|
    test "the owner's browser #{offset.zero? ? "at" : "one second after"} the curfew leaves with access_denied" do
      before_tokens = ClientToken.count

      with_curfew_offset(offset.seconds) do
        get "/sign/in", params: { ri: "jp" }
      end

      assert_response :see_other
      target = URI.parse(jump_rt_url_from_location_for_test(response.location))
      @base_browser.host!(target.host)
      @base_browser.https!
      @base_browser.get(target.request_uri, headers: navigation_headers(site: "cross-site"))

      assert_response :see_other
      target = URI.parse(jump_rt_url_from_location_for_test(@base_browser.response.location))
      query = Rack::Utils.parse_query(target.query)

      assert_equal [303, "access_denied", @transaction.state],
                   [@base_browser.response.status, query["error"], query["state"]]
      assert_equal "canceled", @transaction.reload.status
      assert_equal before_tokens, ClientToken.count
    end
  end

  test "a social Admission is still usable after the 60 second acceptance expiry within the curfew" do
    # F5: the Binding's acceptance expiry has passed, the curfew has not.
    @binding.update_columns(expires_at: ClientAuthAdmissionBinding.database_now - 1.minute)
    move_curfew!(5.minutes)
    post auth_app_social_google_session_path(ri: "jp")

    assert_response :temporary_redirect
  end

  test "a browser without the ceremony after the curfew gets the uniform error and ends nothing" do
    move_curfew!(-1.second)
    stranger = open_session
    stranger.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    stranger.https!
    stranger.get("/sign/in", params: { ri: "jp" })

    assert_not_equal 303, stranger.response.status
    assert_equal "pending", @transaction.reload.status
  end

  test "the owner's browser after the curfew without its authorization transaction gets the uniform error" do
    move_curfew!(-1.second)
    # A06-9: the Admission keeps pointing at a transaction row that is gone.
    OpBaseAppRecord.connected_to(role: :writing) do
      @transaction.class.connection.execute("SET session_replication_role = replica")
      @transaction.class.where(id: @transaction.id).delete_all
      @transaction.class.connection.execute("SET session_replication_role = origin")
    end
    get "/sign/in", params: { ri: "jp" }

    assert_response :bad_request
  end

  private

  def navigation_headers(site:)
    {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => site,
    }
  end

  def move_curfew!(offset)
    @binding.update_columns(curfew_at: ClientAuthAdmissionBinding.database_now + offset)
  end

  def with_curfew_offset(offset)
    unless offset.zero?
      move_curfew!(offset)
      return yield
    end

    decision_time = ClientAuthAdmissionBinding.database_now
    @binding.update_columns(curfew_at: decision_time)
    ClientAuthAdmissionBinding.stub(:database_now, decision_time) { yield }
  end
end
