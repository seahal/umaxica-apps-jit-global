# typed: false
# frozen_string_literal: true

module StepUpCeremonyTransactionable
  extend ActiveSupport::Concern

  DEFAULT_TTL = 15.minutes
  STATUS_PENDING = "pending"
  STATUS_VERIFIED = "verified"
  STATUS_CONSUMED = "consumed"
  STATUS_CANCELED = "canceled"
  STATUS_EXPIRED = "expired"
  STATUS_REVOKED = "revoked"
  STATUSES = %w(pending verified consumed canceled expired revoked).freeze
  PURPOSES = %w(step_up reauthentication bootstrap credential_registration credential_change).freeze
  RETENTION_PERIOD = 7.days

  included do
    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    class_attribute :ceremony_surface_name, instance_accessor: false
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes

    scope :expired_at, ->(time) { where(arel_table[:expires_at].lteq(time)) }
    scope :consumed, -> { where.not(consumed_at: nil).or(where(status: STATUS_CONSUMED)) }
    scope :canceled, -> { where(status: STATUS_CANCELED) }
    scope :active_at, ->(time) {
      where(arel_table[:expires_at].gt(time)).where(consumed_at: nil, status: STATUS_PENDING)
    }
    scope :pending, -> { where(status: STATUS_PENDING, consumed_at: nil) }
    scope :purgeable_at, lambda { |time, retention_period: RETENTION_PERIOD|
      cutoff = time - retention_period
      where(arel_table[:expires_at].lteq(cutoff))
        .or(where(arel_table[:consumed_at].lteq(cutoff)))
    }

    validates :transaction_id, :surface, :actor_ref, :session_ref, :required_scope, :required_aal, :status,
              :grant_jti, :expires_at, presence: true
    validates :transaction_id, uniqueness: true
    validates :grant_jti, uniqueness: true
    validates :result_jti, uniqueness: true, allow_nil: true
    validates :allowed_methods, presence: true
    validates :surface, inclusion: { in: IdentityStepUpCeremonyContract::SURFACES }
    # @deprecated `required_aal` is a storage label only; remove it after the AAL removal ledger
    # has retired historical rows and signed compatibility fixtures.
    validates :required_aal, inclusion: { in: IdentityStepUpCeremonyContract::AALS }
    validates :aal, inclusion: { in: IdentityStepUpCeremonyContract::AALS }, allow_blank: true
    validates :method, inclusion: { in: IdentityStepUpCeremonyContract::METHODS }, allow_blank: true
    validates :status, inclusion: { in: STATUSES }
    validates :step_up_required, :user_verification_required, :full_reauthentication_required,
              :phishing_resistant_required,
              :require_session_binding, inclusion: { in: [true, false] }
    validates :audience, :token_binding, presence: true
    validate :surface_matches_transaction_class
    validate :allowed_methods_are_valid
    validate :consumed_transaction_has_result
    validate :cancellation_handoff_fields_are_consistent
  end

  class_methods do
    public

    def ceremony_surface(value = nil)
      self.ceremony_surface_name = value.to_s if value
      ceremony_surface_name
    end

    def create_transaction!(surface: ceremony_surface, actor_ref:, session_ref:, required_scope:,
                            required_aal: StepUpRequirement::NO_AAL,
                            step_up_required: true, user_verification_required: false,
                            full_reauthentication_required: false, audience: nil, token_binding: nil,
                            require_session_binding: true, tenant_ref: nil, allowed_methods:,
                            phishing_resistant_required: false, resource_ref: nil, return_to: nil,
                            transaction_id: nil, grant_jti: nil, expires_at: nil, now: nil, purpose: "step_up")
      raise ArgumentError, "unsupported ceremony purpose" unless PURPOSES.include?(purpose)
      raise ArgumentError, "legacy AAL requirements are unsupported" unless required_aal.to_s == StepUpRequirement::NO_AAL

      connection_owner.connected_to(role: :writing) do
        now ||= database_now
        create!(
          purpose: purpose,
          transaction_id: transaction_id.presence || SecureRandom.uuid,
          surface: surface.to_s,
          actor_ref: actor_ref,
          session_ref: session_ref,
          required_scope: required_scope.to_s,
          # @deprecated `required_aal` is retained as a non-authoritative label until the removal
          # ledger permits dropping the column. Explicit AAL demands never reach this writer.
          required_aal: StepUpRequirement::NO_AAL,
          step_up_required: step_up_required,
          user_verification_required: user_verification_required,
          full_reauthentication_required: full_reauthentication_required,
          audience: audience.to_s.presence || "step_up:#{surface}",
          token_binding: token_binding.to_s.presence || session_ref.to_s,
          require_session_binding: require_session_binding,
          tenant_ref: tenant_ref,
          phishing_resistant_required: phishing_resistant_required,
          allowed_methods: serialize_allowed_methods(allowed_methods),
          resource_ref: resource_ref,
          return_to: return_to,
          grant_jti: grant_jti.presence || SecureRandom.uuid,
          expires_at: expires_at || (now + DEFAULT_TTL),
          created_at: now,
          updated_at: now,
        )
      end
    end

    def latest_pending_for(actor_ref:, session_ref:, required_scope:, now: Time.current)
      pending
        .where(actor_ref: actor_ref, session_ref: session_ref, required_scope: required_scope.to_s)
        .where(arel_table[:expires_at].gt(now))
        .order(created_at: :desc, id: :desc)
        .first
    end

    def serialize_allowed_methods(methods)
      list = Array(methods).map(&:to_s)
      list.uniq!
      list.join(",")
    end

    def connection_owner
      if self <= AppTicketRecord
        AppTicketRecord
      elsif self <= OrgTicketRecord
        OrgTicketRecord
      elsif self <= ComTicketRecord
        ComTicketRecord
      else
        ActiveRecord::Base
      end
    end
  end

  public

  def intent = purpose

  def verified? = status == STATUS_VERIFIED

  def record_verification!(method:, aal:, phishing_resistant:, user_verified:, verified_at:, verified_credential_ref:)
    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        unless %w(step_up reauthentication).include?(purpose) && step_up_required && status == STATUS_PENDING &&
            !expired?(now: now)
          raise IdentityStepUpCeremonyContract::Error.new(
            "step-up transaction is not pending",
            code: unavailable_refusal_code(expected_purposes: %w(step_up reauthentication), now: now),
          )
        end
        unless allowed_methods_array.include?(method.to_s) && permitted_ceremony_methods.include?(method.to_s)
          raise IdentityStepUpCeremonyContract::Error.new("step-up method is unavailable", code: "unsupported_method")
        end

        validate_verification_evidence!(
          method: method, aal: aal, phishing_resistant: phishing_resistant, user_verified: user_verified,
          verified_at: verified_at, verified_credential_ref: verified_credential_ref, now: now,
        )

        write_status!(
          STATUS_VERIFIED, method: method.to_s, aal: aal.to_s,
                           phishing_resistant: phishing_resistant, user_verified: user_verified, verified_at: verified_at,
                           result_jti: SecureRandom.uuid, verified_credential_ref: verified_credential_ref,
        )
        self
      end
    end
  end

  # Enrollment proves possession of the proposed authenticator. It is not reauthentication and
  # carries no assurance/freshness claim. Only Base may turn its result into a credential.
  def record_registration_verification!(method:, verified_at:)
    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        unless %w(bootstrap credential_registration).include?(purpose) && status == STATUS_PENDING &&
            !expired?(now: now) && !step_up_required && !phishing_resistant_required &&
            !user_verification_required && !full_reauthentication_required &&
            %w(passkey totp).include?(method) && allowed_methods_array.include?(method) &&
            permitted_ceremony_methods.include?(method) && verified_at &&
            verified_at >= created_at && verified_at <= now && verified_at < expires_at
          raise IdentityStepUpCeremonyContract::Error.new("registration evidence is invalid", code: "invalid_evidence")
        end

        write_status!(
          STATUS_VERIFIED, method: method, aal: "none", phishing_resistant: false, user_verified: false,
                           verified_at: verified_at, result_jti: SecureRandom.uuid, verified_credential_ref: nil,
        )
        self
      end
    end
  end

  def prepare_result_delivery!(result_digest:, ttl:)
    raise ArgumentError, "invalid result digest" unless result_digest.is_a?(String) &&
      result_digest.match?(/\A[0-9a-f]{64}\z/)
    raise ArgumentError, "result TTL must be positive" unless ttl.positive?

    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        unless verified? && !expired?(now: now)
          raise IdentityStepUpCeremonyContract::Error.new(
            "step-up result is unavailable",
            code: unavailable_refusal_code(expected_purposes: [purpose], now: now),
          )
        end

        update!(
          result_digest: result_digest, result_generation: result_generation + 1,
          result_expires_at: [now + ttl, expires_at].min,
        )
        [self, result_generation]
      end
    end
  end

  def prepare_cancellation_handoff!(reference:, ciphertext:)
    unless reference.is_a?(String) && reference.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
      raise ArgumentError, "invalid cancellation handoff reference"
    end
    raise ArgumentError,
          "invalid cancellation handoff ciphertext" unless ciphertext.is_a?(String) && ciphertext.present?

    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        if cancellation_handoff_ref.present? &&
            (cancellation_handoff_ref != reference || cancellation_handoff_ciphertext != ciphertext)
          raise IdentityStepUpCeremonyContract::Error.new(
            "cancellation handoff is already bound", code: "transaction_conflict",
          )
        end
        update!(cancellation_handoff_ref: reference, cancellation_handoff_ciphertext: ciphertext) if
          cancellation_handoff_ref.blank? && cancellation_handoff_ciphertext.blank?
        self
      end
    end
  end

  def commit_cancellation!(now:, cancellation_handoff_digest: nil)
    unless cancellation_handoff_digest.nil? ||
        (cancellation_handoff_digest.is_a?(String) && cancellation_handoff_digest.match?(/\A[0-9a-f]{64}\z/))
      raise ArgumentError, "invalid cancellation handoff digest"
    end

    if canceled?
      if cancellation_handoff_digest.present? && self.cancellation_handoff_digest.present? &&
          self.cancellation_handoff_digest != cancellation_handoff_digest
        raise IdentityStepUpCeremonyContract::Error.new(
          "cancellation handoff is already bound", code: "transaction_conflict",
        )
      end
      update!(cancellation_handoff_digest:) if cancellation_handoff_digest.present? && self.cancellation_handoff_digest.blank?
      return self
    end

    attributes = { canceled_at: now }
    if cancellation_handoff_digest.present?
      attributes[:cancellation_handoff_digest] = cancellation_handoff_digest
    end
    write_status!(STATUS_CANCELED, **attributes)
  end

  def result_delivery_matches?(result_digest:, result_generation:, now: nil)
    now ||= self.class.database_now
    return false unless verified? || consumed?
    return false unless result_digest.is_a?(String) && result_digest.match?(/\A[0-9a-f]{64}\z/)
    return false unless result_generation.is_a?(Integer) && result_generation.positive?
    return false unless self.result_digest && result_expires_at && result_expires_at > now && !expired?(now: now)

    self.result_generation == result_generation &&
      ActiveSupport::SecurityUtils.secure_compare(self.result_digest, result_digest)
  end

  def grant_claims(now: Time.current)
    {
      "surface" => surface,
      "actor_ref" => actor_ref,
      "session_ref" => session_ref,
      "transaction_id" => transaction_id,
      "jti" => grant_jti,
      "required_scope" => required_scope,
      "required_aal" => required_aal,
      "step_up_required" => step_up_required,
      "user_verification_required" => user_verification_required,
      "full_reauthentication_required" => full_reauthentication_required,
      "audience" => audience,
      "token_binding" => token_binding,
      "require_session_binding" => require_session_binding,
      "tenant_ref" => tenant_ref,
      "phishing_resistant_required" => phishing_resistant_required,
      "allowed_methods" => allowed_methods_array,
      "resource_ref" => resource_ref,
      "return_to" => return_to,
      "exp" => expires_at.to_i,
      "iat" => now.to_i,
    }.compact
  end

  # Names why this transaction cannot serve a request that needs it open, for the ceremony log.
  def unavailable_refusal_code(expected_purposes:, now:)
    return "malformed_request" unless expected_purposes.include?(purpose)

    case status
    when STATUS_CONSUMED then "transaction_already_completed"
    when STATUS_CANCELED then "transaction_canceled"
    when STATUS_REVOKED then "transaction_revoked"
    when STATUS_EXPIRED then "transaction_expired"
    when STATUS_PENDING, STATUS_VERIFIED
      expired?(now: now) ? "transaction_expired" : "transaction_unavailable"
    else
      raise IdentityStepUpCeremonyContract::Error, "unknown step-up transaction status: #{status.inspect}"
    end
  end

  def allowed_methods_array
    allowed_methods.to_s.split(",").filter_map(&:presence)
  end

  def expired?(now: Time.current)
    expires_at <= now
  end

  def consumed? = status == STATUS_CONSUMED

  def canceled? = status == STATUS_CANCELED

  # The callers below hold the actor, session and row locks and have validated the request; these
  # methods perform the write, so that no other class writes a step-up transaction status.
  #
  # Repeating a cancellation converges on the first result. Every other write to a terminal
  # transaction is refused by write_status!.
  # Persists an expiry that the caller already decided. Read-only paths refuse an expired
  # transaction through expired? and never call this.
  def commit_expiry!
    write_status!(STATUS_EXPIRED)
  end

  def commit_revocation!(now:)
    write_status!(STATUS_REVOKED, revoked_at: now)
  end

  def commit_consumption!(now:)
    unless %w(step_up reauthentication).include?(purpose) && status == STATUS_VERIFIED
      raise IdentityStepUpCeremonyContract::Error.new(
        "step-up transaction is not ready for consumption",
        code: unavailable_refusal_code(expected_purposes: %w(step_up reauthentication), now: now),
      )
    end

    write_status!(STATUS_CONSUMED, consumed_at: now)
  end

  # Passkey and TOTP registration arrive verified by Auth. Email registration is confirmed inside
  # Base, so it has no Auth evidence step and is consumed directly from pending.
  def commit_registration_consumption!(now:, method:, registered_credential_ref:)
    unless %w(bootstrap credential_registration).include?(purpose) &&
        %w(passkey totp email_otp).include?(method.to_s) &&
        !step_up_required && !phishing_resistant_required && !user_verification_required &&
        !full_reauthentication_required
      raise IdentityStepUpCeremonyContract::Error.new(
        "registration transaction is not ready for consumption", code: "transaction_unavailable",
      )
    end

    attributes = { consumed_at: now, verified_credential_ref: registered_credential_ref }
    if status == STATUS_PENDING
      attributes.merge!(
        method: method, aal: "none", phishing_resistant: false, user_verified: false,
        verified_at: now, result_jti: SecureRandom.uuid,
      )
    end
    write_status!(STATUS_CONSUMED, **attributes)
  end

  private

  # The single write point for a step-up transaction status, and the only place that decides
  # whether a transition is permitted.
  #
  #   pending  -> verified                          Auth recorded evidence
  #   pending  -> consumed                          email registration only (confirmed inside Base)
  #   verified -> consumed                          Base finalized
  #   pending | verified -> canceled | expired | revoked
  #
  # consumed, canceled, expired and revoked are terminal.
  def write_status!(target, **attributes)
    current = status_in_database
    unless transition_permitted?(current, target, attributes)
      raise IdentityStepUpCeremonyContract::Error.new(
        "step-up transition from #{current} to #{target} is not permitted",
        code: transition_refusal_code(current),
      )
    end

    update!(status: target, **attributes)
  end

  def transition_permitted?(current, target, attributes)
    case [current, target]
    when [STATUS_PENDING, STATUS_VERIFIED], [STATUS_VERIFIED, STATUS_CONSUMED],
         [STATUS_PENDING, STATUS_CANCELED], [STATUS_PENDING, STATUS_EXPIRED], [STATUS_PENDING, STATUS_REVOKED],
         [STATUS_VERIFIED, STATUS_CANCELED], [STATUS_VERIFIED, STATUS_EXPIRED], [STATUS_VERIFIED, STATUS_REVOKED]
      true
    when [STATUS_PENDING, STATUS_CONSUMED]
      %w(bootstrap credential_registration).include?(purpose) && !step_up_required &&
        !phishing_resistant_required && !user_verification_required && !full_reauthentication_required &&
        attributes[:method] == "email_otp"
    else
      false
    end
  end

  def transition_refusal_code(current)
    case current
    when STATUS_CONSUMED then "transaction_already_completed"
    when STATUS_CANCELED then "transaction_canceled"
    when STATUS_EXPIRED then "transaction_expired"
    when STATUS_REVOKED then "transaction_revoked"
    when STATUS_PENDING, STATUS_VERIFIED then "transaction_unavailable"
    else raise IdentityStepUpCeremonyContract::Error, "unknown step-up transaction status: #{current.inspect}"
    end
  end

  def validate_verification_evidence!(method:, aal:, phishing_resistant:, user_verified:, verified_at:,
                                      verified_credential_ref:, now:)
    unless verified_credential_ref.is_a?(String) && verified_credential_ref.present? &&
        verified_at && verified_at >= created_at && verified_at <= now && verified_at < expires_at &&
        valid_legacy_label?(method: method, aal: aal) &&
        [true, false].include?(phishing_resistant) &&
        [true, false].include?(user_verified) &&
        phishing_resistant == (method.to_s == "passkey") &&
        (!phishing_resistant_required || phishing_resistant == true) &&
        (!user_verification_required || user_verified == true)
      raise IdentityStepUpCeremonyContract::Error.new("step-up evidence is invalid", code: "invalid_evidence")
    end
  end

  def valid_legacy_label?(method:, aal:)
    expected = (method.to_s == "email_otp") ? "none" : "aal1"
    IdentityStepUpCeremonyContract::AALS.include?(aal.to_s) && aal.to_s == expected
  end

  def surface_matches_transaction_class
    return if self.class.ceremony_surface.blank? || surface == self.class.ceremony_surface

    errors.add(:surface, "does not match transaction store")
  end

  def allowed_methods_are_valid
    invalid = allowed_methods_array - IdentityStepUpCeremonyContract::METHODS
    errors.add(:allowed_methods, "contains invalid methods") if invalid.present?
  end

  def consumed_transaction_has_result
    return unless status == STATUS_CONSUMED

    errors.add(:result_jti, "is required for consumed transaction") if result_jti.blank?
    errors.add(:method, "is required for consumed transaction") if method.blank?
    errors.add(:aal, "is required for consumed transaction") if aal.blank?
    errors.add(:verified_at, "is required for consumed transaction") if verified_at.blank?
    errors.add(:user_verified, "is required for consumed transaction") unless [true, false].include?(user_verified)
    return unless %w(step_up reauthentication).include?(purpose) && verified_credential_ref.blank?

    errors.add(:verified_credential_ref, "is required for step-up consumption")

  end

  def cancellation_handoff_fields_are_consistent
    ref_present = cancellation_handoff_ref.present?
    ciphertext_present = cancellation_handoff_ciphertext.present?
    errors.add(:cancellation_handoff_ref, "must be paired with ciphertext") if ref_present != ciphertext_present

    return unless persisted?

    if will_save_change_to_cancellation_handoff_ref? && cancellation_handoff_ref_in_database.present? &&
        cancellation_handoff_ref != cancellation_handoff_ref_in_database
      errors.add(:cancellation_handoff_ref, "cannot change after issuance")
    end
    if will_save_change_to_cancellation_handoff_ciphertext? && cancellation_handoff_ciphertext_in_database.present? &&
        cancellation_handoff_ciphertext != cancellation_handoff_ciphertext_in_database
      errors.add(:cancellation_handoff_ciphertext, "cannot change after issuance")
    end
    if will_save_change_to_cancellation_handoff_digest? && cancellation_handoff_digest_in_database.present? &&
        cancellation_handoff_digest != cancellation_handoff_digest_in_database
      errors.add(:cancellation_handoff_digest, "cannot change after cancellation")
    end

  end
end
