# frozen_string_literal: true

require "test_helper"
require "timeout"
require "webauthn/fake_client"

class SignUpPasskeyTerminationHttpTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    # No fixtures load here, and a structure-loaded test database carries no reference rows, so the
    # rows this flow references are ensured instead of relying on rows another test left behind.
    [
      ClientStatus, ClientVisibility, ClientMfaStatus, ClientTelephoneStatus, ClientSignUpFlowStatus,
      ClientSignUpFlowCleanupStatus,
    ]
      .each(&:ensure_defaults!)
    ClientSecurityMode.insert_missing_fixed_ids!(ClientSecurityMode::DEFAULTS)
    @protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "authentication",
      params: {
        client_id: "core-app-jp",
        redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
        response_type: "code",
        scope: "openid profile",
        prompt: "create",
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
      },
    ).transaction
    admission = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: @parent, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    @binding = ClientAuthAdmissionBinding.find_by!(entry_ref: admission.reference)
    @attached, sid = ClientAuthCeremonySession.issue!
    @binding.attach_auth_session!(auth_session: @attached, confirmation_ref: SecureRandom.uuid)
    @binding.confirm_base!(base_token: nil, browser_digest: @binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: admission.reference, surface: "app", expected_intent: "sign_up", binding: @binding, raw_auth_sid: sid,
    )
    @ceremony, @sid = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: sid,
      authorization_transaction_ref: @parent.transaction_id,
    )
    @binding.redeem!(auth_session: @attached, admitted_auth_session: @ceremony)
    @actor = Client.create!(
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP, security_mode_id: ClientSecurityMode::NORMAL,
    )
    @telephone = ClientTelephone.create!(
      user: @actor, raw_number: "+1202555#{SecureRandom.random_number(10_000).to_s.rjust(4, "0")}",
      confirm_policy: true, user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    nonce = SecureRandom.hex(32)
    now = ClientSignUpFlow.database_now
    @flow = ClientSignUpFlow.create!(
      auth_admission_binding: @binding, principal_id: @actor.id,
      pending_contact_type: "telephone", pending_contact_id: @telephone.id,
      entry_method: "telephone", step: "contact", status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
      nonce_digest: ClientSignUpFlow.digest_nonce(nonce), issued_at: now,
      expires_at: (now + 3.minutes).change(usec: 0),
    )
    issuance = TelephoneSignUpOtpIssuer.call(flow: @flow, telephone: @telephone, session_nonce: nonce)

    assert_predicate issuance, :success?
    @otp_transaction = issuance.transaction
    verified = TelephoneSignUpOtpVerificationCommitter.call(
      flow: @flow, telephone: @telephone, session_nonce: nonce, code: issuance.code,
    )

    assert_predicate verified, :verified_evidence?
    %i(verify_contact enter_guardrail enter_checkpoint).each do |event|
      transition = SignUpStateMachine.call(ticket: @flow, event: event, actor_context: nil)

      assert_predicate transition, :success?
    end
    cleared = SignUpStateMachine.call(
      ticket: @flow, event: :clear_requirement, actor_context: nil,
      payload: { requirement: :otp, checkpoint_version: @flow.reload.checkpoint_version },
    )

    assert_predicate cleared, :success?
    continuity = { "session_id" => SecureRandom.hex(16), "_csrf_token" => SecureRandom.urlsafe_base64(32) }
    state = SignUpSessionState.for(continuity, surface: :app)
    state.cycle_payload = { "public_id" => @flow.public_id, "nonce" => nonce }
    state.sequence_id = @flow.public_id
    state.telephone_otp = { "public_id" => @telephone.public_id, "otp_verified" => true }
    cookie_request = ActionDispatch::TestRequest.create
    jar = ActionDispatch::Cookies::CookieJar.build(cookie_request, {})
    session_key = Rails.application.config.session_options.fetch(:key)
    jar.encrypted[session_key] = { value: continuity }
    @browser = open_session
    @browser.host!(@host)
    @browser.https!
    _session_cookie = @browser.cookies.merge(
      "#{session_key}=#{Rack::Utils.escape(jar[session_key])}", URI.parse("https://#{@host}/"),
    )
    sid_key = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    _auth_cookie = @browser.cookies.merge("#{sid_key}=#{Rack::Utils.escape(@sid)}", URI.parse("https://#{@host}/"))
    @headers = {
      "Origin" => "https://#{@host}",
      "Sec-Fetch-Site" => "same-origin",
      "X-CSRF-Token" => continuity.fetch("_csrf_token"),
    }
    @fields = { ri: "jp", fb: SignFlowBindingCodec.encode(flow: @flow, surface: :app) }
    @browser.post("/sign/up/check/telephone/passkey", params: @fields, headers: @headers, as: :json)

    assert_equal 200, @browser.response.status
    options = @browser.response.parsed_body
    fake_client = WebAuthn::FakeClient.new("https://#{@host}", encoding: :base64url)
    @registration = fake_client.create(
      challenge: options.fetch("options").fetch("challenge"),
      rp_id: options.fetch("options").fetch("rp").fetch("id"), user_verified: true,
    )
    @submission = @fields.merge(
      challenge_id: options.fetch("challenge_id"), checkpoint_version: @flow.reload.checkpoint_version,
      credential: @registration, description: "Concurrent signup Passkey",
    )
  end

  teardown do
    @worker&.join(5)
    @replay_workers&.each { |worker| worker.join(5) }
    if @actor
      ClientSecretIssuance.where(client_id: @actor.id).delete_all
      ClientPasskey.where(user_id: @actor.id).delete_all
      ClientSecretAuditOutbox.where(client_ref: @actor.public_id).delete_all
      ClientPasskeyAuditOutbox.where(actor_ref: @actor.public_id).delete_all
    end
    @otp_transaction&.reload&.delete
    @flow&.reload&.delete
    @binding&.reload&.delete
    @parent&.reload&.delete
    @ceremony&.reload&.delete
    @attached&.reload&.delete
    @telephone&.reload&.delete
    @actor&.reload&.delete
    ActionController::Base.allow_forgery_protection = @protection
  end

  test "two real HTTP Passkey saves serialize one pending credential and one Secret allocation" do
    @browser.post("/sign/up/check/telephone/passkey", params: @fields, headers: @headers, as: :json)

    assert_equal 200, @browser.response.status
    options = @browser.response.parsed_body
    fake_client = WebAuthn::FakeClient.new("https://#{@host}", encoding: :base64url)
    credential = fake_client.create(
      challenge: options.fetch("options").fetch("challenge"),
      rp_id: options.fetch("options").fetch("rp").fetch("id"), user_verified: true,
    )
    replay = open_session
    replay.host!(@host)
    replay.https!
    @browser.cookies.for(URI.parse("https://#{@host}/")).split("; ").each do |cookie|
      _copied_cookie = replay.cookies.merge(cookie, URI.parse("https://#{@host}/"))
    end
    replay_fields = @fields.merge(
      challenge_id: options.fetch("challenge_id"), checkpoint_version: @flow.reload.checkpoint_version,
      credential: credential, description: "Concurrent signup Passkey",
    )
    pid_queue = Queue.new
    pids = []
    waited = false
    principal_available = false
    OpBaseAppRecord.transaction do
      ClientSignUpFlow.lock.find(@flow.id)
      @replay_workers =
        [[@browser, @submission], [replay, replay_fields]].map do |browser, fields|
          Thread.new do
            OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              pid_queue << Integer(connection.select_value("SELECT pg_backend_pid()"))
              browser.patch("/sign/up/check/telephone/passkey", params: fields, headers: @headers, as: :json)
              browser.response.status
            end
          rescue StandardError => e
            e
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        end
      pids = Timeout.timeout(10) { Array.new(2) { pid_queue.pop } }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |observer|
        loop do
          events =
            OpBaseAppRecord.uncached do
              observer.select_value("SELECT pg_stat_clear_snapshot()::text")
              pids.map do |pid|
                observer.select_value("SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(pid)}")
              end
            end
          waited = events.all?("Lock")
          break if waited || @replay_workers.any? { |worker| !worker.alive? } ||
            Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          sleep 0.01
        end
      end
      begin
        Client.transaction(requires_new: true) do
          Client.lock("FOR UPDATE NOWAIT").find(@actor.id)
          principal_available = true
        end
      rescue ActiveRecord::LockWaitTimeout
        principal_available = false
      end
    end
    statuses = Timeout.timeout(10) { @replay_workers.map(&:value) }

    assert_equal 2, pids.uniq.length
    assert waited, "both distinct verified HTTP requests wait on the same Flow row"
    assert principal_available, "neither Flow waiter owns the principal row"
    assert_equal [201, 201], statuses
    assert_equal 1, ClientPasskey.where(user_id: @actor.id).count
    assert_equal ClientPasskey.where(user_id: @actor.id).sole.id, @flow.reload.pending_passkey_registration_id
    assert_equal 1, ClientSecretIssuance.where(sign_up_flow_ref: @flow.public_id).count
    assert_equal 0, ClientToken.where(user_id: @actor.id).count
    SignUpTermination.call(cycle: @flow, event: :cancel)

    assert_predicate @flow.reload, :cleanup_completed?
    assert_equal 0, ClientPasskey.where(user_id: @actor.id).count
  end

  %i(cancel before at after).each do |ending|
    test "HTTP Passkey save after a Flow-lock wait handles #{ending} at the deadline without stale authority" do
      pid_queue = Queue.new
      waited = false
      principal_available = false
      clock_now = OpBaseAppRecord.database_now
      OpBaseAppRecord.stub(:database_now, -> { clock_now }) do
        OpBaseAppRecord.transaction do
          ClientSignUpFlow.lock.find(@flow.id)
          @worker =
            Thread.new do
              OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                pid_queue << Integer(connection.select_value("SELECT pg_backend_pid()"))
                @browser.patch("/sign/up/check/telephone/passkey", params: @submission, headers: @headers, as: :json)
                @browser.response.status
              end
            rescue StandardError => e
              e
            ensure
              ActiveRecord::Base.connection_handler.clear_active_connections!
            end
          worker_pid = Timeout.timeout(10) { pid_queue.pop }
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
          OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |observer|
            loop do
              event =
                OpBaseAppRecord.uncached do
                  observer.select_value("SELECT pg_stat_clear_snapshot()::text")
                  observer.select_value(
                    "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(worker_pid)}",
                  )
                end
              waited = event == "Lock"
              break if waited || !@worker.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

              sleep 0.01
            end
          end
          begin
            Client.transaction(requires_new: true) do
              Client.lock("FOR UPDATE NOWAIT").find(@actor.id)
              principal_available = true
            end
          rescue ActiveRecord::LockWaitTimeout
            principal_available = false
          end
          case ending
          when :cancel
            SignUpTermination.call(cycle: @flow, event: :cancel)
          when :before
            clock_now = @flow.expires_at - Rational(1, 1_000_000)
          when :at
            clock_now = @flow.expires_at
          when :after
            clock_now = @flow.expires_at + Rational(1, 1_000_000)
          end
        end
        status = Timeout.timeout(10) { @worker.value }

        assert waited, "the real HTTP save reaches a PostgreSQL Flow-lock wait after WebAuthn verification"
        assert principal_available, "the waiting HTTP save does not hold the principal row"
        if ending == :before
          assert_equal 201, status
          assert_predicate @flow.reload, :sign_up_checkpoint_pending?
          assert_not_nil @flow.pending_passkey_registration_id
          assert_equal 1, ClientPasskey.where(user_id: @actor.id).count
          assert_equal 1, ClientSecretIssuance.where(sign_up_flow_ref: @flow.public_id).count
          SignUpTermination.call(cycle: @flow, event: :cancel)
        else
          assert_equal 409, status
          assert_nil @flow.reload.pending_passkey_registration_id
        end
        if %i(at after).include?(ending)
          # D-177: the late save is only refused; the Flow stays untouched until the expiry job.
          assert_not_predicate @flow.reload, :sign_up_terminal?
          assert_equal 0, ClientPasskey.where(user_id: @actor.id).count
          # Stay past the deadline so the later lapse assertions read the same clock as the job.
          travel_to(@flow.expires_at + 1.second)
          SignUpExpiryJob.perform_now
        end
        if %i(cancel before).include?(ending)
          assert_predicate @flow.reload, :sign_up_cancelled?
        else
          assert_predicate @flow.reload, :sign_up_expired?
        end

        assert_predicate @flow, :cleanup_completed?
        assert_predicate @actor.reload, :lapsed?
        assert_predicate @telephone.reload, :lapsed?
        assert_equal 0, ClientPasskey.where(user_id: @actor.id).count
        issuances = ClientSecretIssuance.where(sign_up_flow_ref: @flow.public_id)

        assert_equal (ending == :before) ? 1 : 0, issuances.count
        principal_now = Client.database_now

        assert issuances.all? { |issuance|
          issuance.discard_at <= principal_now && issuance.purge_eligible_at > issuance.discard_at
        }
        assert_equal 0, ClientToken.where(user_id: @actor.id).count
      end
    end
  end
end
