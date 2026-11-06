# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::SecretsControllerTest < ActionDispatch::IntegrationTest
  include SignInFlowCleanup

  self.fixture_table_names = []
  self.use_transactional_tests = false
  rate_limit_counters!
  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @created_parent_ids = []
    @created_binding_ids = []
    @client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @identifier = "secret-bound-#{SecureRandom.hex(4)}@example.com"
    @client.client_emails.create!(
      address: @identifier, user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    if @client
      parent_scope = ClientOidcAuthorizationTransaction.where(id: Array(@created_parent_ids))
      flow_ids = parent_scope.where.not(secret_sign_in_flow_id: nil).pluck(:secret_sign_in_flow_id)
      flow_ids.concat(ClientSignInFlow.where(principal_id: @client.id).pluck(:id))
      parent_scope.each do |parent|
        parent.update_column(:secret_sign_in_flow_id, nil) if parent.secret_sign_in_flow_id
      end
      binding_scope = ClientAuthAdmissionBinding.where(id: Array(@created_binding_ids))
      ceremony_ids = binding_scope.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact
      binding_scope.delete_all
      ClientAuthCeremonySession.where(id: ceremony_ids.uniq).delete_all
      delete_client_sign_in_flows!(ClientSignInFlow.where(id: flow_ids.uniq))
      parent_scope.delete_all

      ClientSecretAuditOutbox.where(client_ref: @client.public_id).delete_all
      ClientSecretCredential.where(client_id: @client.id).delete_all
      ClientSecretIssuance.where(client_id: @client.id).delete_all
      ClientChronicle.where(subject_type: "Client", subject_id: @client.id.to_s).delete_all
      ClientContactAuditOutbox.where(owner_ref: @client.public_id).delete_all
      ClientEmailHistory.where(user_id: @client.id).delete_all
      ClientEmail.where(user_id: @client.id).delete_all
      ClientAuthorityLock.where(client_id: @client.id).delete_all
      Client.where(id: @client.id).delete_all
    end
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  [
    ["missing", :missing], ["null", nil], ["empty", ""], ["numeric zero", 0],
    ["array", []], ["object", {}], ["31 characters", "a" * 31], ["33 characters", "a" * 33],
    ["invalid Base58", "0" * 32], ["embedded NUL", ("a" * 31) + "\0"],
    ["exact case mismatch", "A" * 32], ["unknown 32-character value", "z" * 32],
  ].each_with_index do |(label, value), index|
    test "admitted HTTP Secret rejects #{label} without credential or session mutation" do
      host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      host! host
      https!
      # Distinct real request addresses keep independent input cases within the
      # existing online limits; rate-limit behavior is not stubbed or disabled.
      headers = {
        "REMOTE_ADDR" => "192.0.2.#{index + 10}",
        "Origin" => "https://#{host}",
        "Sec-Fetch-Site" => "same-origin",
      }
      admission, = open_admitted_secret_page(headers)
      page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
      payload = { "identifier" => @identifier, "cf-turnstile-response" => "synthetic" }
      payload[:secret] = value unless value == :missing
      before = ClientSecretCredential.order(:id).pluck(:id, :claimed_at, :consumed_at, :revoked_at, :discard_at)
      token_count = ClientToken.count
      outbox_count = ClientSecretAuditOutbox.count
      post(
        auth_app_sign_in_secret_path(ri: "jp"),
        params: payload,
        as: :json,
        headers: headers.merge("X-CSRF-Token" => page.fetch("props").fetch("authenticity_token")),
      )

      assert_response :unprocessable_content
      assert_equal before,
                   ClientSecretCredential.order(:id).pluck(:id, :claimed_at, :consumed_at, :revoked_at, :discard_at)
      assert_equal token_count, ClientToken.count
      assert_equal outbox_count, ClientSecretAuditOutbox.count
      assert_nil admission.transaction.reload.secret_sign_in_flow_id
    end
  end

  test "a source transaction conflict is reported as service unavailable without a session" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    headers = { "REMOTE_ADDR" => "192.0.2.60", "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
    open_admitted_secret_page(headers)
    csrf = inertia_props.fetch("authenticity_token")
    token_count = ClientToken.where(user_id: @client.id).count
    failure = ->(**) { raise ClientSecretClaimCommitter::TransactionConflict, "injected outer transaction" }

    ClientSecretClaimCommitter.stub(:call_for_oidc!, failure) do
      post auth_app_sign_in_secret_path(ri: "jp"),
           params: { :identifier => @identifier, :secret => "a" * 32, "cf-turnstile-response" => "synthetic" },
           as: :json, headers: headers.merge("X-CSRF-Token" => csrf)
    end

    assert_response :service_unavailable
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal token_count, ClientToken.where(user_id: @client.id).count
  end

  test "admitted Secret page links back to the sign-in method selection" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    headers = { "REMOTE_ADDR" => "192.0.2.40", "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
    admission, = open_admitted_secret_page(headers)

    assert_response :ok
    back_link = inertia_props.fetch("back_link")

    assert_equal I18n.t("actions.back"), back_link.fetch("label")
    assert_equal "/sign/cancellation?ri=jp", inertia_props.fetch("parent_cancel").fetch("action")
    assert_equal "post", inertia_props.fetch("parent_cancel").fetch("method")
    back_uri = URI.parse(back_link.fetch("href"))

    assert_equal URI.parse(auth_app_sign_in_path(ri: "jp")).path, back_uri.path
    query = Rack::Utils.parse_nested_query(back_uri.query)

    assert_equal "jp", query.fetch("ri")
    assert_nil query["fb"]

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
    ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
    before = [
      admission.transaction.reload.attributes,
      binding.reload.attributes,
      ceremony.reload.attributes,
    ]
    sid_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    auth_sid = cookies[sid_cookie_name]

    assert_nil admission.transaction.reload.secret_sign_in_flow_id
    assert_predicate auth_sid, :present?

    get(back_uri.to_s, headers: headers.merge("Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document"))

    assert_response :ok
    assert_equal before, [
      admission.transaction.reload.attributes,
      binding.reload.attributes,
      ceremony.reload.attributes,
    ]
    assert_nil admission.transaction.reload.secret_sign_in_flow_id
    assert_equal auth_sid, cookies[sid_cookie_name]
  end

  test "T-SC-3: correct OIDC Secret refuses a same-page GET without mutation" do
    now = ClientSecretIssuance.database_now
    issuance = ClientSecretIssuance.create!(
      client: @client, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      browser_session_ref: SecureRandom.urlsafe_base64(24), planned_count: 1,
      expires_at: now + 1.hour, presented_at: now, confirmed_at: now,
    )
    credential = ClientSecretCredential.create!(
      client: @client, issuance:, name: "T-SC-3 credential", password: "a" * 32, confirmed_at: now,
    )
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    headers = {
      "REMOTE_ADDR" => "192.0.2.42", "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
    }
    admission, = open_admitted_secret_page(headers)
    csrf = inertia_props.fetch("authenticity_token")

    post auth_app_sign_in_secret_path(ri: "jp"),
         params: { "identifier" => @identifier, "secret" => "a" * 32, "cf-turnstile-response" => "synthetic" },
         as: :json, headers: headers.merge("X-CSRF-Token" => csrf)

    assert_response :see_other
    assert credential.reload.claimed_at
    parent = admission.transaction.reload

    assert_predicate parent, :pending?
    assert_predicate parent.secret_sign_in_flow_id, :present?
    flow = ClientSignInFlow.find(parent.secret_sign_in_flow_id)
    sid_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    sid = cookies[sid_name]
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(sid)

    assert_predicate ceremony, :authentication_evidence_recorded?
    before = [
      [parent.status_id, parent.secret_sign_in_flow_id, parent.actor_ref, parent.browser_session_ref],
      [flow.state_id, flow.principal_id, flow.token_id],
      [ceremony.status_id, ceremony.authentication_method, ceremony.completed_at, ceremony.cancelled_at,
       ceremony.revoked_at,],
    ]
    credential_facts = credential.attributes.slice("claimed_at", "consumed_at", "claim_operation_id", "discard_at")
    # Compare a digest so assertion output never contains browser session contents.
    session_before_digest = Digest::SHA256.hexdigest(session.to_hash.to_json)

    get new_auth_app_sign_in_secret_path(ri: "jp"), headers: headers

    assert_equal [409, nil, I18n.t("errors.messages.phase_violation_refused"), "private, no-store"], [
      response.status, response.location, response.body, response.headers["Cache-Control"],
    ]
    after = [
      [parent.reload.status_id, parent.secret_sign_in_flow_id, parent.actor_ref, parent.browser_session_ref],
      [flow.reload.state_id, flow.principal_id, flow.token_id],
      [ceremony.reload.status_id, ceremony.authentication_method, ceremony.completed_at, ceremony.cancelled_at,
       ceremony.revoked_at,],
    ]

    assert_equal before, after
    assert_equal credential_facts,
                 credential.reload.attributes.slice("claimed_at", "consumed_at", "claim_operation_id", "discard_at")
    session_after_digest = Digest::SHA256.hexdigest(session.to_hash.to_json)

    assert_equal session_before_digest, session_after_digest, "rejected GET changed the browser session"
    assert_equal sid, cookies[sid_name]
    forbidden_names = (AuthPhaseRefusalResponseBoundary::COOKIE_NAMES + AuthPhaseRefusalResponseBoundary::DBSC_HEADERS)
      .map(&:downcase)
    cookie_lines = Array(response.headers["Set-Cookie"]).flat_map { |header| header.to_s.split("\n") }
    cookie_names = cookie_lines.map { |header| header.split("=", 2).first.downcase }
    response_names = cookie_names + response.headers.to_h.keys.map(&:downcase)

    assert_empty forbidden_names & response_names
  end

  test "A34-2: a valid Secret cannot authenticate an unfinished APP registration" do
    now = ClientSecretIssuance.database_now
    issuance = ClientSecretIssuance.create!(
      client: @client, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      browser_session_ref: SecureRandom.urlsafe_base64(24), planned_count: 1,
      expires_at: now + 1.hour, presented_at: now, confirmed_at: now,
    )
    credential = ClientSecretCredential.create!(
      client: @client, issuance:, name: "A34 unfinished", password: "a" * 32, confirmed_at: now,
    )
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    headers = {
      "REMOTE_ADDR" => "192.0.2.41", "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
    }
    admission = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )
    @created_parent_ids << admission.transaction.id
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
    @created_binding_ids << binding.id
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil, browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: binding.entry_ref, nonce: "n" * 43,
      ),
    )
    sid_key = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    cookies[sid_key] = raw_sid
    # Design D: the entry GET redeems the reference and redirects to the clean sign-in page.
    get(
      auth_app_sign_in_path(ri: "jp"),
      params: { entry_ref: admission.reference },
      headers: headers.merge("Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document"),
    )

    assert_response :see_other
    follow_redirect!(headers: headers)

    assert_response :ok
    phase_binding = nil
    get new_auth_app_sign_in_secret_path(ri: "jp", fb: phase_binding), headers: headers
    csrf = inertia_props.fetch("authenticity_token")
    token_count = ClientToken.where(user_id: @client.id).count
    @client.reload.update!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)

    post auth_app_sign_in_secret_path(ri: "jp", fb: phase_binding),
         params: { :identifier => @identifier, :secret => "a" * 32, "cf-turnstile-response" => "synthetic" },
         as: :json, headers: headers.merge("X-CSRF-Token" => csrf)

    assert_response :unprocessable_content
    assert_nil credential.reload.claimed_at
    assert_equal token_count, ClientToken.where(user_id: @client.id).count
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_nil ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id).secret_sign_in_flow_id
  end

  test "known and unknown identifiers reach the same limit across request addresses" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    headers = { "REMOTE_ADDR" => "192.0.2.80",
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin", }
    admission = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: "n" * 43, base_token: nil,
    )
    @created_parent_ids << admission.transaction.id
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
    @created_binding_ids << binding.id
    ceremony, raw_sid = binding.class.auth_admission_session_class.issue!
    binding.attach_auth_session!(auth_session: ceremony, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil, browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: binding.entry_ref, nonce: "n" * 43,
      ),
    )
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    cookies[cookie_name] = raw_sid
    # Design D: the entry GET redeems the reference and redirects to the clean sign-in page.
    get(
      auth_app_sign_in_path(ri: "jp"),
      params: { entry_ref: admission.reference },
      headers: headers.merge("Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document"),
    )

    assert_response :see_other
    follow_redirect!(headers: headers)

    assert_response :ok
    phase_binding = nil
    get new_auth_app_sign_in_secret_path(ri: "jp", fb: phase_binding), headers: headers
    csrf = inertia_props.fetch("authenticity_token")

    # Failed challenges cannot spend a chosen identifier's shared attempt budget.
    TurnstileVerifierStub.challenge_response = { "success" => false }
    6.times do |index|
      post auth_app_sign_in_secret_path(ri: "jp", fb: phase_binding),
           params: { identifier: @identifier, secret: "z" * 32 },
           headers: headers.merge("REMOTE_ADDR" => "192.0.2.#{200 + index}", "X-CSRF-Token" => csrf)

      assert_response :unprocessable_content
    end
    TurnstileVerifierStub.challenge_response = { "success" => true }
    results = []
    [@identifier, "secret-unknown@example.test"].each_with_index do |identifier, partition|
      statuses = []
      7.times do |index|
        submitted_identifier = (index >= 5) ? " #{identifier.upcase} " : identifier
        post auth_app_sign_in_secret_path(ri: "jp", fb: phase_binding),
             params: { :identifier => submitted_identifier,
                       :secret => "z" * 32,
                       "cf-turnstile-response" => "synthetic", },
             headers: headers.merge(
               "REMOTE_ADDR" => "192.0.2.#{100 + (partition * 10) + index}",
               "X-CSRF-Token" => csrf,
             )
        statuses << response.status

        assert_nil response.headers["Location"]
      end
      results << statuses
    end

    assert_equal [422, 422, 422, 422, 422, 429, 429], results.first
    assert_equal results.first, results.last
    assert_nil admission.transaction.reload.secret_sign_in_flow_id
  end

  test "legacy Secret GET remains absent while canonical actions require browser admission" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    get "/sign/in/secret"

    assert_response :not_found

    assert_no_difference("ClientSecretCredential.count") do
      get new_auth_app_sign_in_secret_path(ri: "jp")

      assert_response :bad_request
    end
    assert_no_difference -> { ClientSecretCredential.where.not(claimed_at: nil).count } do
      assert_no_difference("ClientToken.count") do
        post auth_app_sign_in_secret_path(ri: "jp"), params: { secret: "a" * 32 }

        assert_response :bad_request
      end
    end
  end

  private

  # Admits a Base local sign-in entry into this browser and opens the Secret page through the
  # canonical continuation, returning the admission and the PRIMARY_PENDING phase binding.
  def open_admitted_secret_page(headers)
    admission = OidcTestEntry.issue!(
      surface: "app",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )
    @created_parent_ids << admission.transaction.id
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
    @created_binding_ids << binding.id
    admission_session, raw_auth_sid = binding.class.auth_admission_session_class.issue!
    binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: binding.class.auth_admission_surface_name,
        entry_ref: binding.entry_ref,
        nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      ),
    )
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    cookies[cookie_name] = raw_auth_sid
    # Design D: the entry GET redeems the reference and redirects to the clean sign-in page; there is
    # no form POST of the entry reference.
    get(
      auth_app_sign_in_path(ri: "jp"),
      params: { entry_ref: admission.reference },
      headers: headers.merge("Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document"),
    )

    assert_response :see_other
    follow_redirect!(headers: headers)

    assert_response :ok
    phase_binding = nil
    get(new_auth_app_sign_in_secret_path(ri: "jp", fb: phase_binding), headers: headers)
    [admission, phase_binding]
  end
end
