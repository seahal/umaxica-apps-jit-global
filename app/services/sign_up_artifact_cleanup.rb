# typed: false
# frozen_string_literal: true

# Performs logical deletion of the dependent records owned by a terminal
# sign-up cycle (pending contact, pending passkey, pending actor) and marks
# the cycle's `cleanup_status_id` accordingly.
#
# Concurrency model:
# - Per-cycle work runs entirely inside one `cycle.with_cycle_lock` so that
#   concurrent callers (controller path + worker) cannot interleave the
#   pending -> completed flip with dependent writes.
# - Dependent updates are issued against the dependent's own DB connection
#   (cross-DB, can't be atomic with the cycle lock); failures flip the cycle
#   to `cleanup_status_id = FAILED` so the worker retries.
#
# The worker entry point (`cleanup_pending_for`) pops one row at a time with
# FOR UPDATE SKIP LOCKED so concurrent worker shards make progress.
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
    [ClientSignUpFlow, VisitorSignUpFlow].each do |cycle_class|
      cycle_now = now || cycle_class.database_now
      cleanup_pending_for(cycle_class, now: cycle_now, batch_size: batch_size)
    end
  end

  # Pop one cycle at a time with FOR UPDATE SKIP LOCKED. Holding a large
  # batch lock through long cross-DB cleanup work starves other shards; a
  # single-row claim keeps parallelism even when individual cleanups are slow.
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
          claimed = scope.order(:id).limit(1).lock("FOR UPDATE SKIP LOCKED").first
          break unless claimed

          call(cycle: claimed, now: now)
        end
        break unless claimed
      end
    end
  end

  def self.cleanup_status_ids(cycle_class)
    %w(CANCELLED EXPIRED FAILED).filter_map do |status_name|
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

    cycle.with_cycle_lock do
      cycle.reload
      return cycle if cycle.cleanup_completed?

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
    cycle
  end

  private

  attr_reader :cycle, :now

  def cleanup_supported?
    cycle&.has_attribute?(:cleanup_status_id) && cycle.respond_to?(:with_cycle_lock)
  end

  def increment_attempts_attrs
    return {} unless cycle.has_attribute?(:cleanup_attempts_count)

    { cleanup_attempts_count: cycle.cleanup_attempts_count.to_i + 1 }
  end

  def schedule_dependent_retention!
    dependent_records.each do |record|
      next unless record

      record.class.transaction do
        record.lock!

        if record.is_a?(ClientExternalIdentity)
          revoke_pending_apple_credential(record)
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

  def dependent_records
    case cycle
    when ClientSignUpFlow
      client_dependent_records
    when VisitorSignUpFlow
      visitor_dependent_records
    else
      []
    end
  end

  def client_dependent_records
    actor = Client.find_by(id: cycle.principal_id)
    contact = client_pending_contact(actor)
    return [] unless actor&.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP && client_pending_contact?(contact)

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

  def visitor_dependent_records
    actor = Visitor.find_by(id: cycle.principal_id)
    contact = visitor_pending_contact(actor)
    return [] unless visitor_pending_contact?(contact)

    [contact, visitor_pending_passkey(actor), actor].compact
  end

  def visitor_pending_contact(actor)
    return unless actor

    case cycle.pending_contact_type
    when "email"
      VisitorEmail.find_by(id: cycle.pending_contact_id, visitor_id: actor.id)
    when "telephone"
      VisitorTelephone.find_by(id: cycle.pending_contact_id, visitor_id: actor.id)
    end
  end

  def visitor_pending_passkey(actor)
    return unless actor && cycle.pending_contact_type == "telephone"
    return unless cycle.has_attribute?(:pending_passkey_registration_id)
    return if cycle.pending_passkey_registration_id.blank?

    VisitorPasskey.find_by(id: cycle.pending_passkey_registration_id, visitor_id: actor.id)
  end

  def visitor_pending_contact?(contact)
    case contact
    when VisitorEmail
      contact.visitor_email_status_id == VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP
    when VisitorTelephone
      contact.visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
    else
      false
    end
  end

  def deleted_status_column(record)
    %i(status_id user_email_status_id user_identity_telephone_status_id visitor_email_status_id
       visitor_telephone_status_id).find { |column| record.has_attribute?(column) }
  end

  def deleted_status_id(record)
    case record
    when ClientEmail then deleted_status_id_for(ClientEmailStatus)
    when ClientTelephone then deleted_status_id_for(ClientTelephoneStatus)
    when ClientPasskey then deleted_status_id_for(ClientPasskeyStatus)
    when VisitorEmail then deleted_status_id_for(VisitorEmailStatus)
    when VisitorTelephone then deleted_status_id_for(VisitorTelephoneStatus)
    when VisitorPasskey then deleted_status_id_for(VisitorPasskeyStatus)
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
  # but Client/Visitor for example use bespoke lifecycle columns rather than
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
