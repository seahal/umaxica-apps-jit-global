# frozen_string_literal: true

# Requires self.class.connection_owner and self.class.database_now from the concrete Email ceremony.
module EmailCeremonyOtp
  OTP_PURPOSES = %w(sign_up sign_in recovery withdrawal credential_registration).freeze
  OTP_PURPOSE_OPERATIONS = {
    "sign_up" => %w(sign_up),
    "sign_in" => %w(sign_in),
    "recovery" => %w(recovery),
    "withdrawal" => %w(withdrawal),
    "credential_registration" => %w(registration replacement),
  }.freeze
  OTP_TTL = 5.minutes
  OTP_VERIFIER_KEYS = {
    "app" => "APP_EMAIL_OTP_VERIFIER_KEY",
    "com" => "COM_EMAIL_OTP_VERIFIER_KEY",
    "org" => "ORG_EMAIL_OTP_VERIFIER_KEY",
  }.freeze

  public

  def email_otp_deliverable?(generation:, at:)
    generation.is_a?(String) && generation.present? && generation == otp_generation &&
      status == "pending" && consumed_at.nil? && otp_purpose_operation_valid? &&
      email_otp_deadlines_finite? && expires_at > at &&
      otp_consumed_at.nil? && otp_cancelled_at.nil? && otp_verifier.present? &&
      otp_expires_at && otp_expires_at > at
  end

  def issue_email_otp!(purpose:)
    raise ArgumentError, "unsupported email OTP purpose" unless OTP_PURPOSES.include?(purpose)

    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        unless status == "pending" && consumed_at.nil? && expires_at > now &&
            otp_consumed_at.nil? && otp_cancelled_at.nil?
          raise ArgumentError, "email OTP ceremony is unavailable"
        end
        raise ArgumentError, "email OTP candidate is missing" if email_candidate_ref.blank?
        raise ArgumentError,
              "email OTP purpose does not match operation" unless otp_purpose_operation_valid?(purpose: purpose)
        raise ArgumentError, "email OTP purpose cannot change" if self.purpose && self.purpose != purpose

        issue_email_otp_locked!(purpose: purpose, deadline: [now + OTP_TTL, expires_at].min)
      end
    end
  end

  def reissue_email_otp!
    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        unless email_otp_deliverable?(generation: otp_generation, at: now)
          raise ArgumentError, "Email OTP reissuance is unavailable"
        end

        issue_email_otp_locked!(purpose: purpose, deadline: otp_expires_at)
      end
    end
  end

  def deliver_email_otp!(generation:, code:)
    raise ArgumentError, "email OTP delivery requires a transport block" unless block_given?
    return false unless valid_email_otp_code?(code)

    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        return false unless email_otp_deliverable?(generation: generation, at: now)
        return false unless ActiveSupport::SecurityUtils.secure_compare(otp_verifier, email_otp_digest(code))

        yield
        true
      end
    end
  end

  def verify_email_otp!(code:, purpose:, actor_ref:, session_ref:, operation:, candidate_ref:)
    return false unless valid_email_otp_code?(code)

    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        return false unless email_otp_deliverable?(generation: otp_generation, at: now)
        return false unless self.purpose == purpose && self.actor_ref == actor_ref && self.session_ref == session_ref
        return false unless self.operation == operation && email_candidate_ref == candidate_ref
        return false unless otp_purpose_operation_valid?(purpose: purpose, operation: operation)

        valid = ActiveSupport::SecurityUtils.secure_compare(otp_verifier, email_otp_digest(code))
        return false if block_given? && !yield(valid)
        return false unless valid

        now = self.class.database_now
        return false unless email_otp_deliverable?(generation: otp_generation, at: now)

        result_expiry = [now + 60.seconds, expires_at].min
        receipt = email_otp_receipt_digest(code, verified_at: now, result_expires_at: result_expiry)
        update!(
          otp_consumed_at: now, otp_receipt_verifier: receipt, otp_verifier: nil,
          otp_result_expires_at: result_expiry,
        )
        true
      end
    end
  end

  def email_otp_verified_evidence?(code:, purpose:, actor_ref:, session_ref:, operation:, candidate_ref:)
    email_otp_evidence_matches?(
      code: code, purpose: purpose, actor_ref: actor_ref, session_ref: session_ref,
      operation: operation, candidate_ref: candidate_ref, finalized_registration: false,
    )
  end

  def email_registration_otp_evidence?(code:, actor_ref:, session_ref:, candidate_ref:)
    email_otp_evidence_matches?(
      code: code, purpose: "credential_registration", actor_ref: actor_ref, session_ref: session_ref,
      operation: "registration", candidate_ref: candidate_ref, finalized_registration: true,
    )
  end

  def cancel_email_otp!
    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        return false if otp_consumed_at || otp_cancelled_at

        update!(otp_cancelled_at: self.class.database_now, otp_verifier: nil)
        true
      end
    end
  end

  private

  def email_otp_deadlines_finite?
    [expires_at, otp_expires_at].all? do |deadline|
      deadline.is_a?(Time) || deadline.is_a?(ActiveSupport::TimeWithZone)
    end
  end

  def email_otp_evidence_matches?(code:, purpose:, actor_ref:, session_ref:, operation:, candidate_ref:,
                                  finalized_registration:)
    return false unless valid_email_otp_code?(code)
    return false unless otp_purpose_operation_valid?(purpose: purpose, operation: operation)

    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        return false unless email_otp_receipt_parent_available?(finalized_registration, now) && expires_at > now &&
          otp_consumed_at && otp_consumed_at <= now && otp_cancelled_at.nil? &&
          otp_receipt_verifier.present? && otp_result_expires_at && otp_result_expires_at > now
        return false unless self.purpose == purpose && self.actor_ref == actor_ref && self.session_ref == session_ref
        return false unless self.operation == operation && email_candidate_ref == candidate_ref

        expected = email_otp_receipt_digest(
          code, verified_at: otp_consumed_at,
                result_expires_at: otp_result_expires_at,
        )
        ActiveSupport::SecurityUtils.secure_compare(otp_receipt_verifier, expected)
      end
    end
  end

  def email_otp_receipt_parent_available?(finalized_registration, now)
    (status == "pending" && consumed_at.nil?) ||
      (finalized_registration && status == "consumed" && consumed_at && consumed_at <= now)
  end

  def otp_purpose_operation_valid?(purpose: self.purpose, operation: self.operation)
    OTP_PURPOSE_OPERATIONS.fetch(purpose.to_s, []).include?(operation.to_s)
  end

  def issue_email_otp_locked!(purpose:, deadline:)
    code = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
    self.purpose = purpose
    self.otp_generation = SecureRandom.uuid
    self.otp_expires_at = deadline
    self.otp_verifier = email_otp_digest(code)
    save!
    code
  end

  def valid_email_otp_code?(code)
    code.is_a?(String) && code.encoding.ascii_compatible? && code.valid_encoding? &&
      code.match?(/\A[0-9]{6}\z/)
  end

  def email_otp_receipt_digest(code, verified_at:, result_expires_at:)
    key = ENV.fetch(OTP_VERIFIER_KEYS.fetch(surface))
    raise ArgumentError, "blank email OTP verifier key" if key.blank?

    binding = JSON.generate(
      ["email_verified_receipt", email_otp_digest(code), verified_at.utc.iso8601(6), result_expires_at.utc.iso8601(6)],
    )
    OpenSSL::HMAC.hexdigest("SHA256", key, binding)
  end

  def immutable_email_otp_terminal_facts
    return if otp_consumed_at_in_database.nil? && otp_cancelled_at_in_database.nil?

    protected_fields = %w(
      purpose otp_generation otp_verifier otp_expires_at otp_consumed_at otp_cancelled_at
      otp_receipt_verifier otp_result_expires_at
      surface transaction_id actor_ref session_ref operation email_candidate_ref expires_at
      normalized_email_digest
      bootstrap_ceremony_transaction_ref
    )
    return unless (changes_to_save.keys & protected_fields).any?

    errors.add(:base, "terminal email OTP facts are immutable")
  end

  def email_otp_digest(code)
    key = ENV.fetch(OTP_VERIFIER_KEYS.fetch(surface))
    raise ArgumentError, "blank email OTP verifier key" if key.blank?

    binding = JSON.generate(
      [
        1, surface, "email", transaction_id, purpose, actor_ref, session_ref,
        operation, email_candidate_ref, normalized_email_digest, bootstrap_ceremony_transaction_ref,
        otp_generation, otp_expires_at.utc.iso8601(6), code,
      ],
    )
    OpenSSL::HMAC.hexdigest("SHA256", key, binding)
  end
end
