# frozen_string_literal: true

class ClientSecretAuditOutbox < AppZenithRecord
  EVENTS = %w(
    secret.created secret.renamed secret.claimed secret.consumed secret.revoked
    secret.discarded secret.purged secret.issuance_started secret.presented
    secret.storage_declared secret.issuance_omitted secret.issuance_canceled secret.signup_completed
    secret.issuance_purged
  ).freeze
  REASONS = %w(
    capacity_full passkey_registration manual user_revocation withdrawal flow_expired
    flow_canceled flow_failed flow_halted login_committed payload_unavailable reissue reattempt
  ).freeze

  attr_readonly :event_id, :event_name, :client_ref, :credential_ref, :actor_type,
                :actor_id, :actor_public_ref, :executor_job_id, :operation_ref,
                :occurred_at, :reason, :item_count, :issuance_origin,
                :issuance_browser_session_ref, :issuance_sign_up_flow_ref

  validates :event_id, :client_ref, :operation_ref, :occurred_at, presence: true
  validates :event_name, inclusion: { in: EVENTS }
  validates :reason, inclusion: { in: REASONS }, allow_nil: true
  validates :client_ref, :credential_ref, :actor_public_ref, length: { maximum: 21 }
  validates :item_count, numericality: { only_integer: true,
                                         greater_than_or_equal_to: 0,
                                         less_than_or_equal_to: 20, }, allow_nil: true
  validate :issuance_purge_authority_snapshot

  class << self
    public

    def record!(actor_context:, client_ref:, operation_ref:, occurred_at:, event_name:,
                credential_ref: nil, item_count: nil, reason: nil, executor_job_id: nil,
                issuance_origin: nil, issuance_browser_session_ref: nil, issuance_sign_up_flow_ref: nil)
      unless lease_connection.transaction_open?
        raise ArgumentError, "Secret audit requires the source Zenith transaction"
      end
      unless item_count.nil? || item_count.is_a?(Integer)
        raise ArgumentError, "Secret audit item count must be an integer or absent"
      end

      create!(
        event_id: SecureRandom.uuid, event_name: event_name, client_ref: client_ref,
        credential_ref: credential_ref, operation_ref: operation_ref, occurred_at: occurred_at,
        item_count: item_count, reason: reason, executor_job_id: executor_job_id,
        issuance_origin: issuance_origin, issuance_browser_session_ref: issuance_browser_session_ref,
        issuance_sign_up_flow_ref: issuance_sign_up_flow_ref,
        **actor_attributes(actor_context),
      )
    end

    private

    def actor_attributes(context)
      raise ArgumentError, "Secret audit requires an explicit actor context" unless context.is_a?(ActorValuesContext)

      if context.unauthenticated?
        unless context.subject.equal?(Unauthenticated.instance)
          raise ArgumentError, "anonymous Secret audit cannot contain an authenticated subject"
        end

        return { actor_type: nil, actor_id: nil, actor_public_ref: nil }
      end

      actor = context.subject
      unless context.client? && context.tld == :app && actor.is_a?(Client) && actor.persisted?
        raise ArgumentError, "Secret audit actor must be a verified app Client"
      end

      { actor_type: "Client", actor_id: actor.id, actor_public_ref: actor.public_id }
    end
  end

  def issuance_purge_authority_snapshot
    return unless event_name == "secret.issuance_purged"

    snapshot = [issuance_origin, issuance_browser_session_ref, issuance_sign_up_flow_ref]
    return if snapshot.all?(&:blank?) # Legacy rows remain held by the replay barrier.

    unless issuance_origin.in?(%w(manual passkey_registration)) &&
        (issuance_browser_session_ref.present? ^ issuance_sign_up_flow_ref.present?)
      errors.add(:base, "issuance purge authority snapshot is incomplete")
    end
  end
end
