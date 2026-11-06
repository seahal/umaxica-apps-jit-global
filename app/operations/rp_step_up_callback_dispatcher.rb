# frozen_string_literal: true

# Correlates one authorization response and dispatches its code at most once.
class RpStepUpCallbackDispatcher
  Result = Data.define(:outcome, :return_target, :token_response, :reason_code)

  STATE_FORMAT = /\A[A-Za-z0-9_-]{43}\z/
  MAX_CODE_LENGTH = 4096
  MAX_ERROR_LENGTH = 64
  REJECTED_ATTEMPT_INDEX = "idx_rp_step_up_audit_outboxes_rejected"

  class << self
    public

    def call(...)
      new(...).call
    end
  end

  def initialize(cell:, access_state:, actor:, browser_binding:, state_token:, issuer:, code:, error:)
    @entry = RpStepUpCellRegistry.fetch(cell)
    @access_state = access_state
    @actor = actor
    @browser_binding = browser_binding
    @state_token = state_token
    @issuer = issuer
    @code = code
    @error = error
  end

  public

  def call
    correlation = correlate
    return result(:invalid, reason_code: "invalid_state") unless correlation

    state = correlation.fetch(:state)
    session = correlation.fetch(:session)
    if correlation.fetch(:rejection_code)
      record_attempt_rejected!(correlation, correlation.fetch(:rejection_code))
      return result(:invalid, state.return_target, reason_code: correlation.fetch(:rejection_code))
    end
    return result(:invalid, state.return_target, reason_code: "expired") if expired?(state)

    unless state.state_id == entry.status_class::PENDING
      record_attempt_rejected!(correlation, "duplicate_callback")
      return result(:conflict, state.return_target, reason_code: "duplicate_callback")
    end
    return result(:invalid, state.return_target, reason_code: "malformed_response") unless valid_response_shape?
    return handle_op_error(state) if error.present?

    verifier = StepUpPkceVerifierCipherAdapter.decrypt(ciphertext: state.pkce_verifier_ciphertext)
    dispatch_transition = start_dispatch(state)
    unless dispatch_transition.outcome == :dispatching
      return result(:invalid, state.return_target, reason_code: "expired") if expired?(state)

      record_attempt_rejected!(correlation, "duplicate_callback")
      return result(:conflict, state.return_target, reason_code: "duplicate_callback")
    end

    exchange_and_install(state:, session:, verifier:, dispatch_transition:)
  rescue ActiveRecord::ActiveRecordError
    result(:unavailable, reason_code: "persistence_unavailable")
  end

  private

  attr_reader :entry, :access_state, :actor, :browser_binding, :state_token, :issuer, :code, :error

  def correlate
    return unless valid_state_token?

    state = find_correlated_state
    return unless state

    correlate_session(state)
  end

  def find_correlated_state
    entry.record_class.connected_to(role: :writing) do
      entry.state_class.find_by(state_digest: Digest::SHA256.hexdigest(state_token))
    end
  end

  def correlate_session(state)
    entry.record_class.connected_to(role: :writing) do
      session = entry.session_class.preload(:op_session_binding).find_by(id: state.rp_session_id)
      binding = entry.binding_class.find_by(id: session&.op_session_binding_id)
      identity = entry.identity_binding_class.find_by(id: binding&.identity_binding_id)
      principal = entry.principal_class.find_by(id: identity&.principal_id)
      now = entry.record_class.database_now
      return unless valid_request_access_state?
      return unless live_request_session?(now)
      return unless live_callback_session?(state, session, now) && live_callback_identity?(binding, principal)

      rejection_code =
        if !browser_binding_matches_state?(state)
          "foreign_browser"
        elsif !request_session_matches?(session) || !callback_bindings_match?(state, binding, identity, principal)
          "state_mismatch"
        end

      { state:, session:, rejection_code: }
    end
  end

  def live_callback_session?(state, session, now)
    session && state.expires_at > now && session.active?(now:)
  end

  def live_request_session?(now)
    session = entry.session_class.preload(:op_session_binding).find_by(id: access_state.rp_session.id)
    session && session.public_id == access_state.rp_session.public_id && session.active?(now:)
  end

  def live_callback_identity?(binding, principal)
    binding && principal && !binding.revoked? && !principal.deactivated?
  end

  def callback_bindings_match?(state, binding, identity, principal)
    callback_issuer_matches?(state) && identity_binding_matches?(state, binding, identity, principal) &&
      access_payload_matches?(state, binding, identity)
  end

  def valid_state_token?
    state_token.is_a?(String) && STATE_FORMAT.match?(state_token)
  end

  def valid_request_access_state?
    access_state.is_a?(BrowserRpAuthentication::AccessState) && access_state.status == :valid &&
      access_state.rp_session && access_state.resource&.instance_of?(entry.principal_class) &&
      access_state.payload.is_a?(Hash) && actor.instance_of?(entry.actor_class) &&
      actor.login_allowed? && !actor.deactivated?
  end

  def request_session_matches?(session)
    access_state.rp_session.id == session.id && access_state.rp_session.public_id == session.public_id
  end

  def browser_binding_matches_state?(state)
    return false unless browser_binding.is_a?(String) && STATE_FORMAT.match?(browser_binding)

    expected = Digest::SHA256.hexdigest(["op-mediated-step-up", entry.cell.client_id, browser_binding].join("\0"))
    actual = state.browser_binding_digest
    actual.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  end

  def callback_issuer_matches?(state)
    expected = state.issuer
    issuer.is_a?(String) && issuer.bytesize == expected.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(issuer, expected)
  end

  def identity_binding_matches?(state, binding, identity, principal)
    cell_binding_matches?(state, binding, identity) && principal_matches_access?(identity, principal) &&
      subject_matches_actor?(identity.subject) &&
      binding.sid == access_state.payload["sid"] && session_matches_actor?(state)
  end

  def subject_matches_actor?(subject)
    expected = OidcSubject.for(actor, resource_type: entry.resource_type)
    subject.is_a?(String) && subject.bytesize == expected.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(subject, expected)
  end

  def cell_binding_matches?(state, binding, identity)
    state.realm == entry.cell.realm.upcase && state.client_id == entry.cell.client_id &&
      state.issuer == OidcIssuer.for_resource_type(entry.resource_type) && binding.issuer == state.issuer &&
      binding.realm == entry.cell.realm && binding.client_id == state.client_id && identity.issuer == state.issuer &&
      identity.realm == entry.cell.realm && identity.client_id == state.client_id
  end

  def principal_matches_access?(identity, principal)
    identity.principal_id == principal.id && identity.principal_id == access_state.resource.id
  end

  def session_matches_actor?(state)
    access_state.rp_session.id == state.rp_session_id && access_state.resource.instance_of?(entry.principal_class)
  end

  def access_payload_matches?(state, binding, identity)
    payload = access_state.payload
    payload["iss"] == state.issuer && payload["sid"] == binding.sid && payload["sub"] == identity.subject &&
      payload["client_id"] == state.client_id && payload["aud"] == [state.client_id]
  end

  def record_attempt_rejected!(correlation, rejection_code)
    # The observation is committed on its own; it never changes RP state or credentials.
    entry.record_class.connected_to(role: :writing) do
      entry.record_class.transaction(requires_new: true) do
        state, session, binding, request_session = lock_correlation_context(correlation.fetch(:state))
        next false unless state && session && binding && request_session

        now = entry.record_class.database_now
        next false unless state.expires_at > now && session.active?(now:)
        next false unless request_session.active?(now:)
        next false if binding.revoked?
        next false if rejection_code == "duplicate_callback" && state.state_id == entry.status_class::PENDING

        identity = entry.identity_binding_class.find_by(id: binding.identity_binding_id)
        principal = entry.principal_class.find_by(id: identity&.principal_id)
        next false unless identity && principal && !principal.deactivated?

        StepUpAuditOutboxWriter.call(
          source_key: entry.audit_source_key,
          event_type: "step_up.attempt_rejected",
          realm: entry.cell.realm.upcase,
          client_id: entry.cell.client_id,
          subject_ref: identity.subject,
          context_ref: state.public_id,
          reason_code: rejection_code,
          payload: { context_ref: state.public_id, rejection_code: rejection_code },
          occurred_at: now,
        )
      end
    end
  rescue ActiveRecord::RecordNotUnique => e
    raise unless rejected_attempt_index_conflict?(e)

    false
  end

  def lock_correlation_context(candidate)
    state_candidate = entry.state_class.find_by(id: candidate.id)
    return unless state_candidate

    session_ids = [state_candidate.rp_session_id, access_state.rp_session.id].uniq
    session_ids.sort!
    sessions, bindings = lock_sessions_and_bindings(session_ids)
    return unless sessions && bindings

    state = entry.state_class.lock.find_by(id: state_candidate.id)
    return unless state

    session_by_id = sessions.index_by(&:id)
    binding_by_id = bindings.index_by(&:id)
    session = session_by_id.fetch(state.rp_session_id)
    request_session = session_by_id.fetch(access_state.rp_session.id)
    binding = binding_by_id.fetch(session.op_session_binding_id)
    return unless session.op_session_binding_id == binding.id

    [state, session, binding, request_session]
  end

  def lock_sessions_and_bindings(session_ids)
    sessions = entry.session_class.where(id: session_ids).order(:id).to_a
    return unless sessions.length == session_ids.length

    binding_ids = sessions.map(&:op_session_binding_id)
    binding_ids.uniq!
    binding_ids.sort!
    bindings = entry.binding_class.where(id: binding_ids).order(:id).lock.to_a
    return unless bindings.length == binding_ids.length

    locked_sessions = entry.session_class.preload(:op_session_binding).where(id: session_ids).order(:id).lock.to_a
    return unless locked_sessions.length == session_ids.length

    [locked_sessions, bindings]
  end

  def rejected_attempt_index_conflict?(error)
    cause = error.cause
    result = cause.result if cause.respond_to?(:result)
    reported = result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME).presence
    return reported == REJECTED_ATTEMPT_INDEX if reported

    error.message.include?(REJECTED_ATTEMPT_INDEX)
  end

  def valid_response_shape?
    code_valid = code.is_a?(String) && code.present? && code.length <= MAX_CODE_LENGTH
    error_valid = error.is_a?(String) && error.present? && error.length <= MAX_ERROR_LENGTH
    invalid_nonblank_code = code.present? && !code_valid
    invalid_nonblank_error = error.present? && !error_valid
    !invalid_nonblank_code && !invalid_nonblank_error && (code_valid ^ error_valid)
  end

  def handle_op_error(state)
    if error == "access_denied"
      transition_pending(
        state, entry.status_class::CANCELLED, "user_cancelled", "step_up.cancelled", :cancelled,
        result_reason_code: "user_cancelled",
      )
    else
      transition_pending(
        state, entry.status_class::REFUSED, "op_error", "step_up.refused", :refused,
        result_reason_code: "op_error",
      )
    end
  end

  def transition_pending(state, status_id, reason_code, event_type, outcome, result_reason_code:)
    transition =
      RpStepUpStateTransitionWriter.call(cell: entry.cell, state_ref: state.public_id) do |locked_state,
                                                                                                        _session,
                                                                                                        _binding,
                                                                                                        now|
        next unless locked_state.state_id == entry.status_class::PENDING && locked_state.expires_at > now

        RpStepUpStateTransitionWriter::Decision.new(
          to_status_id: status_id, reason_code:, event_type:, payload: nil, outcome:,
        )
      end
    unless transition.outcome == outcome
      return result(:invalid, state.return_target, reason_code: "expired") if expired?(state)

      return result(:conflict, state.return_target, reason_code: "duplicate_callback")
    end

    result(outcome, state.return_target, reason_code: result_reason_code)
  end

  def start_dispatch(state)
    RpStepUpStateTransitionWriter.call(cell: entry.cell, state_ref: state.public_id) do |locked_state, _session,
                                                                                                _binding, now|
      next unless locked_state.state_id == entry.status_class::PENDING && locked_state.expires_at > now

      RpStepUpStateTransitionWriter::Decision.new(
        to_status_id: entry.status_class::DISPATCHING,
        reason_code: "dispatch_started",
        event_type: nil,
        payload: nil,
        outcome: :dispatching,
      )
    end
  end

  def exchange_and_install(state:, session:, verifier:, dispatch_transition:)
    remaining = 60.seconds - (entry.record_class.database_now - dispatch_transition.occurred_at)
    return mark_indeterminate(state, "dispatch_deadline_passed") unless remaining.positive?

    binding = entry.binding_class.find(session.op_session_binding_id)
    identity = entry.identity_binding_class.find(binding.identity_binding_id)
    token_url = OutboundHttp::LocalBackChannel.url(OidcIssuer.token_endpoint(entry.resource_type).to_s)
    expectation = OidcClientAssertionStepUpExpectationValue.new(grant: binding.sid, subject: identity.subject)
    exchange = OidcOpTokenClient.authorization_code(
      client_id: entry.cell.client_id,
      token_url:,
      code:,
      redirect_uri: registered_redirect_uri,
      code_verifier: verifier,
      step_up_expectation: expectation,
      deadline: monotonic_now + remaining,
      require_https: OutboundHttp::LocalBackChannel.require_https?(token_url),
    )
    return mark_refused(state) if exchange.outcome == :refused
    return mark_indeterminate(state, "exchange_timeout") unless exchange.success?

    install_verified_response(state, exchange.token_response)
  end

  def install_verified_response(state, token_response)
    access_result = OidcOpAccessTokenVerifier.new(
      access_token: token_response_value(token_response, :access_token),
      client_id: entry.cell.client_id,
      realm: entry.cell.realm,
      issuer: state.issuer,
      audience: entry.cell.client_id,
      jwks_client: OidcOpJwksClient.for_resource_type(entry.resource_type),
    ).call
    id_result = OidcOpIdTokenVerifier.new(
      id_token: token_response_value(token_response, :id_token),
      client_id: entry.cell.client_id,
      realm: entry.cell.realm,
      issuer: state.issuer,
      expected_nonce_digest: state.nonce_digest,
      expected_max_age: 300,
      jwks_client: OidcOpJwksClient.for_resource_type(entry.resource_type),
    ).call
    return mark_indeterminate(state, "exchange_timeout") unless access_result.success? && id_result.success? &&
      event_claims_match?(access_result.payload, id_result.payload)

    installed = RpStepUpInstaller.call(
      cell: entry.cell,
      state_ref: state.public_id,
      actor:,
      access_payload: access_result.payload,
      id_payload: id_result.payload,
      token_response:,
    )
    result_from_installation(installed, state)
  end

  def result_from_installation(installed, state)
    case installed.outcome
    when :installed
      result(:installed, state.return_target, installed.token_response)
    when :refused
      result(:refused, state.return_target, reason_code: "installation_refused")
    when :stale, :unchanged
      result(:stale, state.return_target, reason_code: "state_changed")
    else
      raise ArgumentError, "unsupported RP step-up installation outcome: #{installed.outcome.inspect}"
    end
  end

  def event_claims_match?(access, id)
    %w(iss sub sid aud acr amr auth_time).all? { |claim| access[claim] == id[claim] }
  end

  def mark_refused(state)
    transition =
      RpStepUpStateTransitionWriter.call(cell: entry.cell, state_ref: state.public_id) do |locked_state,
                                                                                                        _session,
                                                                                                        _binding,
                                                                                                        _now|
        next unless locked_state.state_id == entry.status_class::DISPATCHING

        RpStepUpStateTransitionWriter::Decision.new(
          to_status_id: entry.status_class::REFUSED,
          reason_code: "op_error",
          event_type: "step_up.refused",
          payload: nil,
          outcome: :refused,
        )
      end
    result(transition.outcome, state.return_target, reason_code: "op_error")
  end

  def mark_indeterminate(state, reason_code)
    transition =
      RpStepUpStateTransitionWriter.call(cell: entry.cell, state_ref: state.public_id) do |locked_state,
                                                                                                        _session,
                                                                                                        _binding,
                                                                                                        _now|
        next unless locked_state.state_id == entry.status_class::DISPATCHING

        RpStepUpStateTransitionWriter::Decision.new(
          to_status_id: entry.status_class::INDETERMINATE,
          reason_code:,
          event_type: "step_up.indeterminate",
          payload: nil,
          outcome: :indeterminate,
        )
      end
    result(transition.outcome, state.return_target, reason_code: reason_code)
  end

  def registered_redirect_uri
    client = OidcClientRegistry.find!(entry.cell.client_id)
    uri =
      client.redirect_uris_by_realm.fetch(entry.resource_type).find do |candidate|
        URI.parse(candidate).path == entry.callback_path
      end
    raise KeyError, "Base step-up callback URI is not registered" unless uri

    uri
  end

  def token_response_value(response, key)
    value = response[key] || response[key.to_s]
    value.is_a?(String) ? value : ""
  end

  def result(outcome, return_target = nil, token_response = nil, reason_code: nil)
    reason_code ||= default_reason_code(outcome)
    Result.new(outcome:, return_target:, token_response:, reason_code:)
  end

  def default_reason_code(outcome)
    case outcome
    when :installed then nil
    when :cancelled then "user_cancelled"
    when :conflict then "duplicate_callback"
    when :indeterminate then "outcome_indeterminate"
    when :invalid then "invalid_callback"
    when :refused then "op_refused"
    when :stale then "stale_context"
    when :unavailable then "dependency_unavailable"
    else raise ArgumentError, "unsupported step-up callback outcome: #{outcome.inspect}"
    end
  end

  def expired?(state)
    entry.record_class.connected_to(role: :writing) do
      state.expires_at <= entry.record_class.database_now
    end
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
