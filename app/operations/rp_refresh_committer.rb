# typed: false
# frozen_string_literal: true

# RP Refresh over HTTPS with exact delivery recovery (R5-WU08, one.md section 7.4).
#
# 1. Reserve: under the local session row lock, refuse a revoked/expired session, then record one
#    short attempt (expected installed generation, HMAC of the presented credential, five-second
#    expiry). Commit and release every lock before any network call.
# 2. Dispatch the Refresh to the OP token endpoint with a fresh endpoint-bound assertion and the
#    attempt reference.
# 3. Preserve an uncertain attempt across requests and ask only its read-only delivery query.
#    The predecessor is never resent to the rotation endpoint, even after local installation.
# 4. Verify the returned Access JWT against the OP public JWKS and this session's sid/subject.
# 5. Install under the session and OP-binding locks again: refuse if the session or binding was
#    revoked meanwhile or another attempt already advanced the installed generation.
#
# Transport/dependency failures keep the browser credentials; only a definitive refusal clears them.
class RpRefreshCommitter
  Result =
    Data.define(:outcome, :token_response) do
      def installed? = outcome == :installed
    end

  # installed    - this attempt's tokens are now the session's single installed generation.
  # refused      - the OP definitively refused the credential (clear cookies, new Code Flow).
  # dependency   - the OP could not be reached or answered invalidly; keep cookies, retry later.
  # superseded   - a sibling is in flight or a newer generation won; keep the current cookies.
  # revoked      - the local session or its OP binding is revoked or expired.
  OUTCOMES = %i(installed refused dependency superseded revoked).freeze
  ATTEMPT_TTL = OidcRefreshDeliveryReceipt::TTL
  DISPATCH_BUDGET = 4.0
  HMAC_PURPOSE = "rp_refresh_attempt_input"

  def initialize(cell:, local_session_id:, refresh_token:, issuer:, contract_epoch:, jwks_client:, token_url:,
                 query_url:)
    @cell = cell
    @local_session_id = local_session_id
    @refresh_token = refresh_token
    @issuer = issuer
    @contract_epoch = contract_epoch
    @jwks_client = jwks_client
    @token_url = token_url
    @query_url = query_url
  end

  class << self
    public

    def call(...) = new(...).call
  end

  public

  def call
    record_class.connected_to(role: :writing) do
      attempt, fresh_attempt = reserve_attempt
      next result(:revoked) unless attempt

      @dispatch_deadline = monotonic_now + DISPATCH_BUDGET
      response = fresh_attempt ? dispatch(attempt) : resume_attempt(attempt)
      next result(response) if response.is_a?(Symbol)

      install(attempt, response)
    end
  end

  private

  attr_reader :cell, :local_session_id, :refresh_token, :issuer, :contract_epoch, :jwks_client, :token_url, :query_url

  def reserve_attempt
    with_locked_session do |session, anchor|
      next unless live?(session, anchor)

      prior = model(:RefreshAttempt).where(session: session, input_hmac: input_hmac).order(id: :desc).first
      next [prior, false] if prior

      now = database_now
      attempt = model(:RefreshAttempt).create!(
        session:, input_hmac: input_hmac, expected_installed_generation: session.installed_generation,
        dispatched_at: now, expires_at: now + ATTEMPT_TTL,
      )
      [attempt, true]
    end
  end

  # Returns the token response Hash, or an outcome Symbol when no tokens are available.
  def dispatch(attempt)
    return :refused if attempt.expires_at <= database_now

    outcome = OidcOpTokenClient.refresh(
      client_id: cell.client_id, token_url:, refresh_token:, attempt_ref: attempt.public_id,
      deadline: delivery_deadline(attempt),
    )
    return outcome.token_response if outcome.success?
    return :refused if outcome.outcome == :refused

    mark_uncertain(attempt)
    return :dependency unless outcome.outcome == :indeterminate

    recover_delivery(attempt)
  end

  def resume_attempt(attempt)
    return :refused if attempt.expires_at <= database_now
    return :superseded unless attempt.uncertain_at || attempt.installed_at

    recover_delivery(attempt)
  end

  def recover_delivery(attempt)
    return :refused if attempt.expires_at <= database_now

    recovered = OidcOpTokenClient.query_delivery(
      client_id: cell.client_id, query_url:, refresh_token:, attempt_ref: attempt.public_id,
      deadline: delivery_deadline(attempt),
    )
    return recovered.token_response if recovered.success?

    # A refused query means no receipt for this attempt (window closed or nothing committed); the
    # predecessor may already be rotated, so the browser must start a new Code Flow.
    (recovered.outcome == :refused) ? :refused : :dependency
  end

  def install(attempt, token_response)
    return defer_installation(attempt) if monotonic_now >= @dispatch_deadline

    payload = verified_access_payload(token_response)
    return defer_installation(attempt) unless payload

    with_locked_session do |session, anchor|
      next result(:revoked) unless live?(session, anchor)
      next result(:refused) if attempt.expires_at <= database_now
      next defer_installation(attempt) if monotonic_now >= @dispatch_deadline
      next result(:refused) unless payload_matches?(session, anchor, payload)
      if attempt.installed_at && session.installed_generation == attempt.expected_installed_generation + 1 &&
          session.current_access_jti_digest == Digest::SHA256.hexdigest(payload.fetch("jti"))
        next Result.new(outcome: :installed, token_response:)
      end
      next result(:superseded) unless session.installed_generation == attempt.expected_installed_generation

      session.update!(
        installed_generation: session.installed_generation + 1,
        current_access_jti_digest: Digest::SHA256.hexdigest(payload.fetch("jti")),
        current_access_expires_at: Time.zone.at(payload.fetch("exp")),
      )
      model(:RefreshAttempt).where(id: attempt.id).update_all(installed_at: database_now) # rubocop:disable Rails/SkipsModelValidations
      Result.new(outcome: :installed, token_response:)
    end
  end

  def verified_access_payload(token_response)
    verification = OidcOpAccessTokenVerifier.new(
      access_token: token_response[:access_token].to_s, client_id: cell.client_id, realm: cell.realm, issuer:,
      audience: cell.client_id, contract_epoch:, jwks_client:,
    ).call
    verification.success? ? verification.payload : nil
  end

  def mark_uncertain(attempt)
    model(:RefreshAttempt).where(id: attempt.id).update_all(uncertain_at: database_now) # rubocop:disable Rails/SkipsModelValidations
  end

  def defer_installation(attempt)
    mark_uncertain(attempt)
    result(:dependency)
  end

  def with_locked_session
    record_class.transaction do
      session = model(:Session).find_by(public_id: local_session_id)
      next yield(nil, nil) unless session

      # Callback and logout lock the permanent sid anchor before touching its sessions.
      anchor = model(:OpSessionBinding).includes(identity_binding: :principal).lock.find(session.op_session_binding_id)
      session.lock!
      yield session, anchor
    end
  end

  def live?(session, anchor)
    session && anchor && session.revoked_at.nil? && session.absolute_expires_at > database_now &&
      anchor.revoked_at.nil? && anchor.identity_binding.present? &&
      anchor.identity_binding.principal.disabled_at.nil?
  end

  def payload_matches?(session, anchor, payload)
    identity = anchor.identity_binding
    session.contract_epoch == payload.fetch("umx_contract_epoch") &&
      anchor.sid == payload.fetch("sid") && anchor.issuer == payload.fetch("iss") &&
      anchor.realm == cell.realm && anchor.client_id == cell.client_id &&
      identity.issuer == anchor.issuer && identity.realm == anchor.realm &&
      identity.client_id == anchor.client_id && identity.subject == payload.fetch("sub")
  end

  def input_hmac
    key = Rails.application.key_generator.generate_key(HMAC_PURPOSE, 32)
    OpenSSL::HMAC.digest("SHA256", key, refresh_token.to_s)
  end

  def database_now
    record_class.database_now
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def delivery_deadline(attempt)
    [@dispatch_deadline, monotonic_now + (attempt.expires_at - database_now)].min
  end

  def record_class
    "#{cell.record_prefix}Record".constantize
  end

  def model(suffix)
    "#{cell.record_prefix}#{suffix}".constantize
  end

  def result(outcome)
    Result.new(outcome:, token_response: nil)
  end
end
