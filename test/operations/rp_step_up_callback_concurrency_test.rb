# frozen_string_literal: true

require "test_helper"
require "timeout"

class RpStepUpCallbackConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  fixtures :clients
  # Avoid loading unrelated Chronicle fixtures through the suite's inherited `fixtures :all`.
  self.fixture_table_names = %w(clients)

  test "two callbacks correlated before dispatch produce only one token request" do
    ready = Queue.new
    release = Queue.new
    outcomes = Queue.new
    calls = Queue.new
    original_decrypt = StepUpPkceVerifierCipherAdapter.method(:decrypt)
    refusal = OidcOpTokenClient::Result.new(outcome: :refused, token_response: nil, error: "invalid_grant")
    workers = []

    StepUpPkceVerifierCipherAdapter.stub(
      :decrypt, lambda { |ciphertext:|
                  ready << true
                  release.pop
                  original_decrypt.call(ciphertext:)
                },
    ) do
      OidcOpTokenClient.stub(
        :authorization_code, ->(**) {
                               calls << true
                               refusal
                             },
      ) do
        2.times do
          workers << Thread.new do
            RpBaseAppRecord.connection_pool.with_connection do
              outcomes << dispatch
            end
          rescue StandardError => e
            outcomes << e
          end
        end
        2.times { Timeout.timeout(10) { ready.pop } }
        2.times { release << true }
        results = 2.times.map { Timeout.timeout(10) { outcomes.pop } }
        results.each { |result| raise result if result.is_a?(Exception) }

        assert_equal %i(conflict refused), results.map(&:outcome).sort_by(&:to_s)
        assert_equal 1, calls.size
      end
    end

    assert_equal RpStepUpStateStatus::REFUSED, @state.reload.state_id
    assert_equal 1, @state.transitions.where(to_state_id: RpStepUpStateStatus::DISPATCHING).count
    assert_equal 1, RpStepUpAuditOutbox.where(
      context_ref: @state.public_id,
      event_type: "step_up.attempt_rejected",
      reason_code: "duplicate_callback",
    ).count
  ensure
    workers.each { |worker| worker.join(10) }
  end

  private

  def setup
    @actor = clients(:one)
    @cell = RpCellBinding.fetch("rp_base_app")
    issuer = OidcIssuer.for_resource_type("client")
    subject = OidcSubject.for(@actor, resource_type: "client")
    sid = SecureRandom.alphanumeric(21)
    @browser_binding = SecureRandom.urlsafe_base64(32)
    @session = RpCallbackCommitter.call(
      cell: @cell, issuer:, subject:, sid:, absolute_expires_at: 1.hour.from_now,
    ).session
    binding = RpBaseAppOpSessionBinding.includes(identity_binding: :principal).find(@session.op_session_binding_id)
    principal = binding.identity_binding.principal
    access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: principal,
      rp_session: @session,
      payload: {
        "iss" => issuer,
        "aud" => [@cell.client_id],
        "sid" => sid,
        "sub" => subject,
        "client_id" => @cell.client_id,
        "authn_ctx" => AuthenticationContextValue::NORMAL_KEY,
      },
      security_context: nil,
    )
    started = RpStepUpStartIssuer.call(
      cell: @cell,
      access_state:,
      actor: @actor,
      browser_binding: @browser_binding,
      return_target: "/settings/security",
    )
    @state = RpStepUpState.find_by!(public_id: started.state_ref)
    @state_token = Rack::Utils.parse_nested_query(URI.parse(started.authorization_url).query).fetch("state")
  end

  def dispatch
    session = RpBaseAppSession.find(@session.id)
    binding = RpBaseAppOpSessionBinding.find(session.op_session_binding_id)
    identity = RpBaseAppIdentityBinding.find(binding.identity_binding_id)
    principal = RpBaseAppPrincipal.find(identity.principal_id)
    RpStepUpCallbackDispatcher.call(
      cell: @cell,
      access_state: BrowserRpAuthentication::AccessState.new(
        status: :valid,
        resource: principal,
        rp_session: session,
        payload: {
          "iss" => @state.issuer,
          "aud" => [@cell.client_id],
          "sid" => binding.sid,
          "sub" => OidcSubject.for(@actor, resource_type: "client"),
          "client_id" => @cell.client_id,
          "authn_ctx" => AuthenticationContextValue::NORMAL_KEY,
        },
        security_context: nil,
      ),
      actor: @actor,
      browser_binding: @browser_binding,
      state_token: @state_token,
      issuer: @state.issuer,
      code: "single-use-code",
      error: nil,
    )
  end

  def teardown
    return unless @session

    RpBaseAppRecord.transaction do
      if @state
        outbox_ids = RpStepUpAuditOutbox.where(context_ref: @state.public_id).pluck(:id)
        RpStepUpAuditOutboxAttempt.where(outbox_id: outbox_ids).delete_all
        RpStepUpAuditOutbox.where(id: outbox_ids).delete_all
        RpStepUpStateTransition.where(owner_id: @state.id).delete_all
        RpStepUpState.where(id: @state.id).delete_all
      end
      RpBaseAppSession.where(id: @session.id).delete_all
      RpBaseAppOpSessionBinding.where(id: @session.op_session_binding_id).delete_all
    end
  ensure
    super
  end
end
