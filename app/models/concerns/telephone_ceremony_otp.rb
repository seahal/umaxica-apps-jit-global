# frozen_string_literal: true

# Requires self.class.connection_owner and self.class.database_now from the concrete Telephone ceremony.
module TelephoneCeremonyOtp
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
    "app" => "APP_TELEPHONE_OTP_VERIFIER_KEY",
    "com" => "COM_TELEPHONE_OTP_VERIFIER_KEY",
    "org" => "ORG_TELEPHONE_OTP_VERIFIER_KEY",
  }.freeze

  public

  def telephone_otp_deliverable?(generation:, at:)
    generation.is_a?(String) && generation.present? && generation == otp_generation &&
      status == "pending" && consumed_at.nil? && otp_purpose_operation_valid? &&
      telephone_otp_deadlines_finite? && expires_at > at &&
      otp_consumed_at.nil? && otp_cancelled_at.nil? && otp_verifier.present? &&
      otp_expires_at && otp_expires_at > at
  end

  def issue_telephone_otp!(purpose:)
    raise ArgumentError, "unsupported telephone OTP purpose" unless OTP_PURPOSES.include?(purpose)

    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        unless status == "pending" && consumed_at.nil? && expires_at > now &&
            otp_consumed_at.nil? && otp_cancelled_at.nil?
          raise ArgumentError, "telephone OTP ceremony is unavailable"
        end
        raise ArgumentError, "telephone OTP candidate is missing" if telephone_candidate_ref.blank?
        raise ArgumentError,
              "telephone OTP purpose does not match operation" unless otp_purpose_operation_valid?(purpose: purpose)
        raise ArgumentError, "telephone OTP purpose cannot change" if self.purpose && self.purpose != purpose

        issue_telephone_otp_locked!(purpose: purpose, deadline: [now + OTP_TTL, expires_at].min)
      end
    end
  end

  def reissue_telephone_otp!
    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        unless telephone_otp_deliverable?(generation: otp_generation, at: self.class.database_now)
          raise ArgumentError, "telephone OTP ceremony is unavailable"
        end

        issue_telephone_otp_locked!(purpose: purpose, deadline: otp_expires_at)
      end
    end
  end

  def deliver_telephone_otp!(generation:, code:)
    raise ArgumentError, "telephone OTP delivery requires a transport block" unless block_given?
    return false unless valid_telephone_otp_code?(code)

    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        return false unless telephone_otp_deliverable?(generation: generation, at: now)
        return false unless ActiveSupport::SecurityUtils.secure_compare(otp_verifier, telephone_otp_digest(code))

        yield
        true
      end
    end
  end

  def verify_telephone_otp!(code:, purpose:, actor_ref:, session_ref:, operation:, candidate_ref:)
    return false unless valid_telephone_otp_code?(code)

    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        return false unless telephone_otp_deliverable?(generation: otp_generation, at: now)
        return false unless self.purpose == purpose && self.actor_ref == actor_ref && self.session_ref == session_ref
        return false unless self.operation == operation && telephone_candidate_ref == candidate_ref
        return false unless otp_purpose_operation_valid?(purpose: purpose, operation: operation)

        valid = ActiveSupport::SecurityUtils.secure_compare(otp_verifier, telephone_otp_digest(code))
        return false if block_given? && !yield(valid)
        return false unless valid

        now = self.class.database_now
        return false unless telephone_otp_deliverable?(generation: otp_generation, at: now)

        result_expiry = [now + 60.seconds, expires_at].min
        receipt = telephone_otp_receipt_digest(code, verified_at: now, result_expires_at: result_expiry)
        update!(
          otp_consumed_at: now, otp_receipt_verifier: receipt, otp_verifier: nil,
          otp_result_expires_at: result_expiry,
        )
        true
      end
    end
  end

  def telephone_otp_verified_evidence?(code:, purpose:, actor_ref:, session_ref:, operation:, candidate_ref:)
    telephone_otp_evidence_matches?(
      code: code, purpose: purpose, actor_ref: actor_ref, session_ref: session_ref,
      operation: operation, candidate_ref: candidate_ref, finalized_registration: false,
    )
  end

  def telephone_registration_otp_evidence?(code:, actor_ref:, session_ref:, candidate_ref:)
    telephone_otp_evidence_matches?(
      code: code, purpose: "credential_registration", actor_ref: actor_ref, session_ref: session_ref,
      operation: "registration", candidate_ref: candidate_ref, finalized_registration: true,
    )
  end

  def cancel_telephone_otp!
    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        return false if otp_consumed_at || otp_cancelled_at

        update!(otp_cancelled_at: self.class.database_now, otp_verifier: nil)
        true
      end
    end
  end

  private

  def issue_telephone_otp_locked!(purpose:, deadline:)
    code = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
    self.purpose = purpose
    self.otp_generation = SecureRandom.uuid
    self.otp_expires_at = deadline
    self.otp_verifier = telephone_otp_digest(code)
    save!
    code
  end

  def telephone_otp_deadlines_finite?
    [expires_at, otp_expires_at].all? do |deadline|
      deadline.is_a?(Time) || deadline.is_a?(ActiveSupport::TimeWithZone)
    end
  end

  def telephone_otp_evidence_matches?(code:, purpose:, actor_ref:, session_ref:, operation:, candidate_ref:,
                                      finalized_registration:)
    return false unless valid_telephone_otp_code?(code)
    return false unless otp_purpose_operation_valid?(purpose: purpose, operation: operation)

    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        return false unless telephone_otp_receipt_parent_available?(finalized_registration, now) && expires_at > now &&
          otp_consumed_at && otp_consumed_at <= now && otp_cancelled_at.nil? &&
          otp_receipt_verifier.present? && otp_result_expires_at && otp_result_expires_at > now
        return false unless self.purpose == purpose && self.actor_ref == actor_ref && self.session_ref == session_ref
        return false unless self.operation == operation && telephone_candidate_ref == candidate_ref

        expected = telephone_otp_receipt_digest(
          code, verified_at: otp_consumed_at,
                result_expires_at: otp_result_expires_at,
        )
        ActiveSupport::SecurityUtils.secure_compare(otp_receipt_verifier, expected)
      end
    end
  end

  def telephone_otp_receipt_parent_available?(finalized_registration, now)
    (status == "pending" && consumed_at.nil?) ||
      (finalized_registration && status == "consumed" && consumed_at && consumed_at <= now)
  end

  def otp_purpose_operation_valid?(purpose: self.purpose, operation: self.operation)
    OTP_PURPOSE_OPERATIONS.fetch(purpose.to_s, []).include?(operation.to_s)
  end

  def valid_telephone_otp_code?(code)
    code.is_a?(String) && code.encoding.ascii_compatible? && code.valid_encoding? &&
      code.match?(/\A[0-9]{6}\z/)
  end

  def telephone_otp_receipt_digest(code, verified_at:, result_expires_at:)
    key = ENV.fetch(OTP_VERIFIER_KEYS.fetch(surface))
    raise ArgumentError, "blank telephone OTP verifier key" if key.blank?

    binding = JSON.generate(
      ["telephone_verified_receipt", telephone_otp_digest(code), verified_at.utc.iso8601(6),
       result_expires_at.utc.iso8601(6),],
    )
    OpenSSL::HMAC.hexdigest("SHA256", key, binding)
  end

  def immutable_telephone_otp_terminal_facts
    return if otp_consumed_at_in_database.nil? && otp_cancelled_at_in_database.nil?

    protected_fields = %w(
      purpose otp_generation otp_verifier otp_expires_at otp_consumed_at otp_cancelled_at
      otp_receipt_verifier otp_result_expires_at
      surface transaction_id actor_ref session_ref operation telephone_candidate_ref expires_at
      normalized_number_digest
    )
    return unless (changes_to_save.keys & protected_fields).any?

    errors.add(:base, "terminal telephone OTP facts are immutable")
  end

  def telephone_otp_digest(code)
    key = ENV.fetch(OTP_VERIFIER_KEYS.fetch(surface))
    raise ArgumentError, "blank telephone OTP verifier key" if key.blank?

    binding = JSON.generate(
      [
        1, surface, "telephone", transaction_id, purpose, actor_ref, session_ref,
        operation, telephone_candidate_ref, normalized_number_digest, otp_generation,
        otp_expires_at.utc.iso8601(6), code,
      ],
    )
    OpenSSL::HMAC.hexdigest("SHA256", key, binding)
  end
end
