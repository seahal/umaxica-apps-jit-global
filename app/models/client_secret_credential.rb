# frozen_string_literal: true

class ClientSecretCredential < AppZenithRecord
  include PublicId
  include Retainable

  MAX_PER_CLIENT = 20
  SECRET_FORMAT = /\A[1-9A-HJ-NP-Za-km-z]{32}\z/

  class InvalidTransition < StandardError; end

  has_secure_password algorithm: :argon2, validations: false

  belongs_to :client, inverse_of: :client_secret_credentials
  belongs_to :issuance, class_name: "ClientSecretIssuance"

  attr_readonly :public_id, :client_id, :issuance_id, :password_digest, :lookup_digest,
                :claimed_at, :claim_operation_id

  validates :name, presence: true, length: { maximum: 255 }
  validates :password_digest, presence: true, length: { maximum: 255 }
  validates :lookup_digest, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :password, format: { with: SECRET_FORMAT }, allow_nil: true
  validate :persisted_revocation_is_immutable, on: :update
  validate :revocation_has_source_audit, on: :update
  validate :terminal_issuance_cannot_confirm_candidate
  validate :confirmation_has_source_audit, on: :update
  validate :persisted_confirmation_is_immutable, on: :update

  scope :available_at, ->(at) {
    where.not(confirmed_at: nil).where(claimed_at: nil, claim_operation_id: nil, revoked_at: nil)
      .where("discard_at > ?", at)
  }

  public

  # confirmed_at needs a validated transition, so fixed Rails writer guards
  # protect ordinary assignments instead of excluding the column from every save.
  def write_attribute(name, value)
    verify_lifecycle_assignment!(name)
    super
  end

  def _write_attribute(name, value)
    verify_lifecycle_assignment!(name)
    super
  end

  def commit_storage_confirmation!(actor_context:, at:)
    unless (at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)) &&
        self.class.lease_connection.transaction_open?
      raise InvalidTransition, "Secret confirmation requires its source transaction and timestamp"
    end

    unless storage_confirmation_context_matches?(actor_context) && confirmed_at.nil? &&
        claimed_at.nil? && claim_operation_id.nil? && revoked_at.nil? &&
        created_at <= at && accessible?(at) && issuance.reload.confirmed_at == at
      raise InvalidTransition, "Secret confirmation requires its owning storage declaration"
    end

    unless storage_confirmation_source_recorded?(at)
      raise InvalidTransition, "Secret confirmation requires its matching source audit"
    end

    @storage_confirmation_write = true
    self.confirmed_at = at
    save!
    self
  ensure
    @storage_confirmation_write = false
  end

  # Generic attribute assignment cannot write a persisted lifecycle fact.
  # The dedicated transition below validates and commits it with source audit.
  def revoked_at=(value)
    raise ActiveRecord::ReadonlyAttributeError, "revoked_at" if persisted?

    super
  end

  def commit_management_revocation!(actor_context:, at:, purge_at:)
    unless persisted? && actor_context.is_a?(ActorValuesContext) && actor_context.client? &&
        actor_context.tld == :app && actor_context.surface == :base &&
        actor_context.subject.is_a?(Client) && actor_context.subject.id == client_id
      raise InvalidTransition, "Secret revocation requires its owning Base app Client"
    end
    unless (at.is_a?(Time) || at.is_a?(ActiveSupport::TimeWithZone)) &&
        (purge_at.is_a?(Time) || purge_at.is_a?(ActiveSupport::TimeWithZone)) && purge_at > at
      raise InvalidTransition, "Secret revocation requires ordered finite timestamps"
    end

    AppZenithRecord.connected_to(role: :writing) do
      client.with_lock(requires_new: true) do
        with_lock do
          unless available_at?(at: at) && created_at <= at &&
              AuthMethodGuard.can_remove_secret_credential?(client, self)
            raise InvalidTransition, "Secret is unavailable for management revocation"
          end

          @management_revocation_write = true
          self[:revoked_at] = at
          self.discard_at = at
          self.purge_eligible_at = purge_at
          operation_ref = SecureRandom.uuid
          %w(secret.revoked secret.discarded).each do |event_name|
            ClientSecretAuditOutbox.record!(
              actor_context: actor_context.with(subject: client), client_ref: client.public_id,
              credential_ref: public_id, operation_ref: operation_ref, occurred_at: at,
              event_name: event_name, reason: "user_revocation",
            )
          end
          save!
        end
      end
    end
    self
  ensure
    @management_revocation_write = false
  end

  def available_at?(at:)
    confirmed_at.present? && claimed_at.nil? && claim_operation_id.nil? &&
      revoked_at.nil? && accessible?(at)
  end

  def matches_secret?(raw)
    return false unless raw.is_a?(String) && raw.valid_encoding? && raw.ascii_only? && SECRET_FORMAT.match?(raw)
    return false unless lookup_digest.present? && password_digest.present?

    expected = SignSecretLookupDigest.digest(raw)
    return false unless ActiveSupport::SecurityUtils.secure_compare(expected, lookup_digest)

    authenticate(raw).present?
  end

  private

  def storage_confirmation_context_matches?(context)
    persisted? && context.is_a?(ActorValuesContext) && context.client? &&
      context.tld == :app && context.surface == :base && context.subject.is_a?(Client) &&
      context.subject.id == client_id
  end

  def verify_lifecycle_assignment!(name)
    return unless persisted?

    attribute = name.to_s
    if attribute == "confirmed_at" && !@storage_confirmation_write
      raise ActiveRecord::ReadonlyAttributeError, "confirmed_at"
    end
    if attribute == "discard_at" && discard_at_in_database != Float::INFINITY
      raise ActiveRecord::ReadonlyAttributeError, "discard_at"
    end
    return unless attribute == "revoked_at" && !@management_revocation_write

    raise ActiveRecord::ReadonlyAttributeError, "revoked_at"
  end

  # Rails uses this hook for update_columns and touch; those APIs never perform
  # a source-audited, validated lifecycle transition.
  def verify_readonly_attribute(name)
    if %w(confirmed_at revoked_at).include?(name.to_s)
      raise ActiveRecord::ReadonlyAttributeError, name.to_s
    end
    # A finite discard timestamp is an irreversible credential fact. Retention
    # updates and name changes cannot turn it back into an available Secret.
    if name.to_s == "discard_at" && discard_at_in_database != Float::INFINITY
      raise ActiveRecord::ReadonlyAttributeError, "discard_at"
    end

    super
  end

  def persisted_confirmation_is_immutable
    return unless confirmed_at_in_database && will_save_change_to_confirmed_at?

    errors.add(:confirmed_at, "cannot change a terminal storage declaration fact")
  end

  def confirmation_has_source_audit
    return unless confirmed_at && confirmed_at_in_database.nil? && will_save_change_to_confirmed_at?
    return if issuance.reload.confirmed_at == confirmed_at && storage_confirmation_source_recorded?(confirmed_at)

    errors.add(:confirmed_at, "requires its matching source audit and storage declaration")
  end

  def storage_confirmation_source_recorded?(at)
    created = ClientSecretAuditOutbox.exists?(
      client_ref: client.public_id, credential_ref: public_id, operation_ref: issuance.origin_operation_id,
      event_name: "secret.created", occurred_at: at,
      actor_type: "Client", actor_id: client_id, actor_public_ref: client.public_id,
    )
    created && ClientSecretAuditOutbox.exists?(
      client_ref: client.public_id, credential_ref: nil, operation_ref: issuance.origin_operation_id,
      event_name: "secret.storage_declared", occurred_at: at, item_count: issuance.planned_count,
      actor_type: "Client", actor_id: client_id, actor_public_ref: client.public_id,
    )
  end

  def terminal_issuance_cannot_confirm_candidate
    return unless confirmed_at && issuance && (issuance.canceled_at || issuance.planned_count.zero?)

    errors.add(:issuance, "canceled or omitted issuance cannot confirm a candidate")
  end

  def persisted_revocation_is_immutable
    return unless revoked_at_in_database && will_save_change_to_revoked_at?

    errors.add(:revoked_at, "cannot change a terminal revocation fact")
  end

  # Source events are a persistence prerequisite, not session authorization.
  # Only the management operation verifies the current browser and Step-Up.
  def revocation_has_source_audit
    return unless revoked_at && revoked_at_in_database.nil? && will_save_change_to_revoked_at?

    events = ClientSecretAuditOutbox.where(
      credential_ref: public_id, client_ref: client.public_id, actor_type: "Client", actor_id: client_id,
      actor_public_ref: client.public_id, occurred_at: revoked_at, reason: "user_revocation",
      event_name: %w(secret.revoked secret.discarded),
    )
    return if events.group(:operation_ref).having("COUNT(DISTINCT event_name) = 2").exists?

    errors.add(:revoked_at, "requires its matching source audit transaction")
  end
end
