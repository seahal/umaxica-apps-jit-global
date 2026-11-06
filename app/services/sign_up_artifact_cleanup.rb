# typed: false
# frozen_string_literal: true

# Performs logical deletion of the dependent records owned by a terminal
# sign-up cycle (pending contact, pending passkey, pending actor) and marks
# the cycle's `cleanup_status_id` accordingly.
#
# Concurrency model:
# - Per-cycle work runs inside `cycle.with_cycle_lock` so concurrent callers (controller path +
#   worker) cannot interleave the pending -> completed flip with dependent writes. For a bound APP
#   flow, that boundary locks the Client before the OP Flow and rechecks the flow binding.
# - Contact, Passkey, audit and actor changes share the principal transaction. The OP Flow and
#   principal databases cannot commit atomically; a failure leaves retryable cleanup facts.
#
# The worker entry point reads one candidate without an OP row lock. Its per-cycle lock
# serializes duplicate selections after the actor-first lock order is established.
class SignUpArtifactCleanup
  BATCH_SIZE = 100
  PHYSICAL_PURGE_DELAY = SignUpTermination::PHYSICAL_PURGE_DELAY
  # Cap permanent-failure retries so the worker stops hot-looping on rows
  # that will never succeed (e.g. dependent records in an unexpected state).
  # Rows past the cap are excluded from the worker scan and require manual
  # intervention; the failure surface stays bounded.
  MAX_CLEANUP_ATTEMPTS = 10

  def self.call(cycle:, now: Time.current)
    new(cycle: cycle, now: now).call
  end

  def self.cleanup_pending!(now: nil, batch_size: BATCH_SIZE)
    [ClientSignUpFlow].each do |cycle_class|
      cycle_now = now || cycle_class.database_now
      cleanup_pending_for(cycle_class, now: cycle_now, batch_size: batch_size)
    end
  end

  # Read one candidate at a time without taking an OP row lock before the actor lock.
  # Concurrent workers may select the same candidate; with_cycle_lock rechecks its state
  # under the required actor-first order, so later workers observe completed cleanup.
  def self.cleanup_pending_for(cycle_class, now:, batch_size:)
    attempts_column_present = cycle_class.column_names.include?("cleanup_attempts_count")
    cleanup_status_ids_to_pick = [
      cycle_class.cleanup_status_id_for(:pending),
      cycle_class.cleanup_status_id_for(:failed),
    ]

    cycle_class.connection_class_for_self.connected_to(role: :writing) do
      batch_size.times do
        claimed = nil
        cycle_class.transaction do
          scope = cycle_class
            .where(cleanup_status_id: cleanup_status_ids_to_pick)
            .where(status_id: cleanup_status_ids(cycle_class))
          scope = scope.where(cleanup_attempts_count: ...MAX_CLEANUP_ATTEMPTS) if attempts_column_present
          claimed = scope.order(:id).limit(1).first
          break unless claimed

          call(cycle: claimed, now: now)
        end
        break unless claimed
      end
    end
  end

  def self.cleanup_status_ids(cycle_class)
    %w(CANCELLED EXPIRED FAILED HALTED).filter_map do |status_name|
      cycle_class.status_id_for(status_name)
    rescue KeyError
      nil
    end
  end

  def initialize(cycle:, now: Time.current)
    @cycle = cycle
    @now = now
  end

  def call
    return cycle unless cleanup_supported?
    return cycle if cycle.cleanup_completed?

    cleanup_from_principal_snapshot
    cycle
  rescue SignUpCleanupStalePrincipalBindingError
    # A stale unbound Flow takes the OP lock before the actor lock. Drop that lock, refresh the
    # binding, and retry through ClientSignUpFlow#with_cycle_lock's actor-first branch.
    cycle.reload
    call
  end

  private

  attr_reader :cycle, :now

  def cleanup_from_principal_snapshot
    principal_id_before_lock = cycle.principal_id
    cycle.with_cycle_lock do
      cycle.reload
      ensure_principal_binding_matches!(principal_id_before_lock)
      cleanup_locked_cycle
    end
  end

  def ensure_principal_binding_matches!(principal_id_before_lock)
    return unless principal_id_before_lock.blank? && cycle.principal_id.present?

    raise SignUpCleanupStalePrincipalBindingError,
          "Sign-up Flow changed from unbound to bound before cleanup acquired its lock"
  end

  def cleanup_locked_cycle
    return cycle if cycle.cleanup_completed?
    return cycle unless cycle.sign_up_terminal?

    begin
      attempt_attrs = increment_attempts_attrs
      cycle.update!(
        attempt_attrs.merge(
          cleanup_status_id: cycle.cleanup_status_id_for(:pending),
          cleanup_attempted_at: now,
          cleanup_error_code: nil,
        ),
      )
      schedule_dependent_retention!
      cycle.update!(
        cleanup_status_id: cycle.cleanup_status_id_for(:completed),
        cleanup_completed_at: now,
        cleanup_error_code: nil,
      )
    rescue ActiveRecord::ActiveRecordError, ArgumentError => e
      cycle.update!(
        cleanup_status_id: cycle.cleanup_status_id_for(:failed),
        cleanup_attempted_at: now,
        cleanup_error_code: "#{e.class.name}: #{e.message}".first(255),
      )
    end
  end

  def cleanup_supported?
    cycle&.has_attribute?(:cleanup_status_id) && cycle.respond_to?(:with_cycle_lock)
  end

  def increment_attempts_attrs
    return {} unless cycle.has_attribute?(:cleanup_attempts_count)

    { cleanup_attempts_count: cycle.cleanup_attempts_count.to_i + 1 }
  end

  def schedule_dependent_retention!
    owner, actor_class =
      case cycle
      when ClientSignUpFlow then [AppZenithRecord, Client]
      else raise ArgumentError, "unsupported sign-up cleanup flow"
      end

    owner.connected_to(role: :writing) do
      # The decision and all dependent writes share one principal transaction. A failed actor
      # retirement must roll back the contact, Passkey and audit facts so a retry sees pending data.
      actor_class.transaction(requires_new: true) do
        actor = actor_class.lock.find_by(id: cycle.principal_id)
        dependent_records(actor).each do |record|
          record.lock!

          if record.is_a?(ClientExternalIdentity)
            revoke_pending_apple_credential(record)
            record.destroy!
            next
          end

          if record.is_a?(ClientPasskey)
            PasskeyAuditOutbox.record_for!(
              passkey: record,
              event_type: "passkey.registration_cancelled",
              surface: "app",
              actor_ref: nil,
              operation_ref: cycle.public_id,
              occurred_at: record.class.database_now,
              metadata: { reason: "sign_up_cancelled" },
            )
            record.destroy!
            next
          end

          status_column = deleted_status_column(record)
          deleted_id = deleted_status_id(record)

          if record.respond_to?(:discard_now!)
            record.discard_now!(purge_after: PHYSICAL_PURGE_DELAY, now: now)
            record.update!(status_column => deleted_id) if status_column && deleted_id
          else
            attrs = retention_attrs(record)
            attrs[status_column] = deleted_id if status_column && deleted_id
            record.update!(attrs) if attrs.any?
          end
        end
      end
    end
  end

  def dependent_records(actor)
    case cycle
    when ClientSignUpFlow
      client_dependent_records(actor)
    else
      []
    end
  end

  def client_dependent_records(actor)
    return [] unless actor&.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP
    # WU-05d P5: a social pending Client before Finalization has no contact and no External Identity.
    # Under the principal lock it is retired only while nothing has been linked to it.
    if cycle.pending_contact_type == "social_identity" && cycle.pending_contact_id.nil?
      return ClientExternalIdentity.exists?(client_id: actor.id) ? [] : [actor]
    end

    contact = client_pending_contact(actor)
    return [] unless client_pending_contact?(contact)

    [contact, client_pending_passkey(actor), actor].compact
  end

  def client_pending_contact(actor)
    return unless actor

    case cycle.pending_contact_type
    when "email"
      ClientEmail.find_by(id: cycle.pending_contact_id, user_id: actor.id)
    when "telephone"
      ClientTelephone.find_by(id: cycle.pending_contact_id, user_id: actor.id)
    when "social_identity"
      client_social_identity(actor)
    end
  end

  def client_social_identity(actor)
    provider = cycle.social_provider.presence || cycle.entry_method
    return unless %w(apple google).include?(provider)

    identity = ExternalAuthentication::IdentityRepositoryFactory.current.build(provider).find_for_user(actor)
    identity if identity && identity.id.to_s == cycle.pending_contact_id.to_s
  end

  def client_pending_passkey(actor)
    return unless actor && cycle.pending_contact_type == "telephone"
    return unless cycle.has_attribute?(:pending_passkey_registration_id)
    return if cycle.pending_passkey_registration_id.blank?

    ClientPasskey.find_by(id: cycle.pending_passkey_registration_id, user_id: actor.id)
  end

  def client_pending_contact?(contact)
    case contact
    when ClientEmail
      contact.user_email_status_id == ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP
    when ClientTelephone
      contact.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
    when ClientExternalIdentity
      true
    else
      false
    end
  end

  def deleted_status_column(record)
    %i(status_id user_email_status_id user_identity_telephone_status_id).find { |column| record.has_attribute?(column) }
  end

  def deleted_status_id(record)
    case record
    when ClientEmail then deleted_status_id_for(ClientEmailStatus)
    when ClientTelephone then deleted_status_id_for(ClientTelephoneStatus)
    when ClientPasskey then deleted_status_id_for(ClientPasskeyStatus)
    end
  end

  def revoke_pending_apple_credential(_identity)
    nil
  end

  def deleted_status_id_for(status_class)
    status_class.ensure_defaults! if status_class.respond_to?(:ensure_defaults!)
    status_class::DELETED
  end

  # Fallback for dependent records that do not include Retainable. Most do,
  # but Client for example uses bespoke lifecycle columns rather than
  # the Retainable contract.
  def retention_attrs(record)
    discard_at = [record.created_at, now].compact.max
    purge_eligible_at = now + PHYSICAL_PURGE_DELAY
    attrs = {}
    attrs[:discard_at] = discard_at if record.has_attribute?(:discard_at)
    attrs[:purge_eligible_at] = purge_eligible_at if record.has_attribute?(:purge_eligible_at)
    attrs
  end
end
