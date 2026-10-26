# typed: false
# frozen_string_literal: true

# Durable Back-Channel Logout delivery for the OP authority-stop participants (WU-15; D-26, D-117,
# D-121, BX-4, BX-10).
#
# The stop transaction wrote one participant row per RP grant it ended; that row is the outbox.
# Solid Queue runs this job after the stop commits and from the every-minute recurring sweep, so a
# lost enqueue or crashed worker never loses a logout. Lease: a short OP transaction claims due
# pending rows (FOR UPDATE SKIP LOCKED), stamps a lease and an attempt, and commits; delivery runs
# with no transaction open; the outcome is recorded in another short transaction. A row ends as
# acknowledged, permanently refused, or expired at its retry deadline, never assumed delivered.
class OpOutboxDispatchJob < ApplicationJob
  queue_as :default

  REALMS = [
    { realm: "app", participant_class: OpAppAuthorityStopParticipant },
    { realm: "com", participant_class: OpComAuthorityStopParticipant },
    { realm: "org", participant_class: OpOrgAuthorityStopParticipant },
  ].freeze
  BATCH_SIZE = 50
  LEASE = 30.seconds
  MAX_BACKOFF = 1.hour
  # BX-4: a 413 and a redirect are stable endpoint misconfigurations for this fixed-size request.
  # Every other failure is retried until the participant deadline. Alert outcomes are logged at error.
  PERMANENT = %w(http_400 http_404 http_405 http_410 http_413 invalid_endpoint).freeze
  ALERT = %w(http_401 http_403 http_404 http_405 http_410 http_413 invalid_endpoint).freeze

  public

  def perform
    REALMS.each { |configuration| dispatch(configuration) }
  end

  private

  def dispatch(configuration)
    realm = configuration.fetch(:realm)
    participant_class = configuration.fetch(:participant_class)
    expire_overdue(participant_class)
    lease(participant_class).each do |participant|
      next unless renew_lease(participant_class, participant)

      outcome = OidcBackchannelLogoutClient.call(
        endpoint: participant.endpoint_identity,
        logout_token: OpLogoutTokenIssuer.call(participant:, realm:),
      )
      record(participant_class, participant, outcome)
    end
  end

  def pending_id = OpAuthorityStopReference.participant_status_id("pending")

  def lease(participant_class)
    participant_class.transaction do
      now = participant_class.database_now
      rows = participant_class.lock("FOR UPDATE SKIP LOCKED")
        .where(status_id: pending_id).where(next_attempt_at: ..now).where(lease_expires_at: ..now)
        .where("deadline_at > ?", now)
        .order(:next_attempt_at).limit(BATCH_SIZE).to_a
      rows.select { |row| row.claim_delivery!(lease_seconds: LEASE.to_i) }
    end
  end

  # BX-10: past its deadline a pending participant is expired, not retried forever.
  def expire_overdue(participant_class)
    participant_class.transaction do
      now = participant_class.database_now
      participant_class.lock("FOR UPDATE SKIP LOCKED").where(status_id: pending_id)
        .where(deadline_at: ..now).order(:deadline_at, :id).limit(BATCH_SIZE).each do |row|
        log_outcome(row, "expired", level: :warn) if row.expire_delivery_if_due!
      end
    end
  end

  def record(participant_class, participant, outcome)
    participant_class.transaction do
      current = participant_class.lock.find(participant.id)
      next unless current.status_id == pending_id && current.delivery_attempts == participant.delivery_attempts

      retry_delay_seconds = retry_delay_seconds_for(current, outcome)
      result = current.record_delivery_result!(outcome:, retry_delay_seconds:)
      recorded_outcome = (result == :expired) ? "expired" : outcome.to_s
      level = (result == :expired) ? :warn : (alert_outcome?(outcome) ? :error : :info)
      log_outcome(current, recorded_outcome, level:) unless result == :stale
    end
  end

  # A batch can take longer than one lease. Recheck ownership before each send so a reclaimed row is
  # not also sent by the old worker, and renew without holding locks across HTTP.
  def renew_lease(participant_class, participant)
    participant_class.transaction do
      current = participant_class.lock.find(participant.id)
      next false unless current.status_id == pending_id && current.delivery_attempts == participant.delivery_attempts

      current.renew_delivery_lease!(lease_seconds: LEASE.to_i)
    end
  end

  def retry_delay_seconds_for(participant, outcome)
    return nil if outcome == :acknowledged || permanent_outcome?(outcome)

    exponent = [participant.delivery_attempts, MAX_BACKOFF.to_i.bit_length].min
    [2**exponent, MAX_BACKOFF.to_i].min
  end

  def permanent_outcome?(outcome)
    return true if PERMANENT.include?(outcome)

    status = http_status(outcome)
    status && (300..399).cover?(status)
  end

  def alert_outcome?(outcome)
    return true if ALERT.include?(outcome)

    status = http_status(outcome)
    status && (300..399).cover?(status)
  end

  def http_status(outcome)
    match = /\Ahttp_(\d{3})\z/.match(outcome.to_s)
    match && Integer(match[1], 10)
  end

  def log_outcome(participant, outcome, level:)
    event = JitLogEvent.format(
      "oidc.backchannel_logout.delivery", client_id: participant.client_id, outcome:,
                                          attempts: participant.delivery_attempts,
    )
    case level
    when :error then Rails.logger.error(event)
    when :info then Rails.logger.info(event)
    when :warn then Rails.logger.warn(event)
    else raise ArgumentError, "unsupported BCL log level #{level.inspect}"
    end
  end
end
