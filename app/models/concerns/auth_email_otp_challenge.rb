# frozen_string_literal: true

# A subordinate one-shot challenge on admitted Auth continuity. It carries no root or RP authority.
# Effective Contact OTP columns remain independent: one browser never rotates another flow's code.
module AuthEmailOtpChallenge
  public

  def issue_email_otp!(contact:, destination:)
    digest = IdentifierBlindIndex.bidx_for_email(destination, realm: email_otp_surface)
    raise ArgumentError, "email destination required" if digest.blank?

    expired_local_parent = false
    result =
      with_email_otp_parent_lock do |parent, now|
        if email_otp_context&.fetch("verified_at")
          raise AuthCeremonySession::InvalidTransition, "email authentication proof is already verified"
        end

        with_email_otp_contact_lock(contact) do |locked|
          now = self.class.database_now
          if expire_email_otp_local_parent!(parent, now)
            expired_local_parent = true
            next nil
          end
          unless active?(now: now) && email_otp_parent_pending?(parent, now)
            raise AuthCeremonySession::InvalidTransition, "email authentication ceremony unavailable"
          end
          if locked && (!locked.binding_effective? || locked.address_digest != digest ||
              !email_otp_owner(locked).login_allowed?)
            raise AuthCeremonySession::InvalidTransition, "email authentication binding unavailable"
          end

          code = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
          context = email_otp_binding_context(locked, digest)
          context.merge!(
            "version" => 1, "generation" => SecureRandom.uuid, "issued_at" => now.utc.iso8601(6),
            "expires_at" => [
              now + EmailOtpPolicy::AUTHENTICATION_TTL, expires_at, email_otp_parent_deadline(parent),
            ].min.utc.iso8601(6),
            "verified_at" => nil, "result_expires_at" => nil, "cancelled_at" => nil,
          )
          context["code_digest"] = AuthEmailOtpCodeDigest.for(context: context, code: code)
          update!(email_otp_context: context)
          (locked && !locked.locked?) ? code : nil
        end
      end
    if expired_local_parent
      raise AuthCeremonySession::InvalidTransition, "email authentication ceremony unavailable"
    end

    result
  end

  def verify_email_otp!(code:)
    return email_otp_refusal(:invalid_code) unless well_formed_email_otp_code?(code)

    with_email_otp_parent_lock do |parent, now|
      context = email_otp_context
      return email_otp_refusal(:missing_challenge) if context.nil?
      raise ArgumentError, "unsupported email OTP context" unless context.fetch("version") == 1
      return email_otp_refusal(:binding_mismatch) unless email_otp_scope_current?(context)
      return email_otp_refusal(:missing_challenge) if context["cancelled_at"]

      contact =
        email_otp_contact_model.find_by(public_id: context.fetch("contact_ref")) if context.fetch("mode") == "real"
      return email_otp_refusal(:binding_unavailable) if context.fetch("mode") == "real" && contact.nil?

      with_email_otp_contact_lock(contact) do |locked|
        now = self.class.database_now
        return email_otp_refusal(:expired) if expire_email_otp_local_parent!(parent, now)
        return email_otp_refusal(:expired) unless active?(now: now) && email_otp_parent_pending?(parent, now)
        return email_otp_refusal(:binding_unavailable) unless email_otp_binding_current?(context, locked)

        if context.fetch("verified_at")
          return email_otp_refusal(:result_expired) if Time.iso8601(context.fetch("result_expires_at")) <= now

          return AuthEmailOtpVerificationResult.new(status: :already_verified, contact: locked)
        end
        return email_otp_refusal(:expired) if Time.iso8601(context.fetch("expires_at")) <= now
        return email_otp_refusal(:locked) if locked&.locked?

        verify_email_otp_comparison!(context, locked, code, now, parent)
      end
    end
  end

  def email_otp_challenge_current?(contact:)
    context = email_otp_context
    return false if context.nil? || context["cancelled_at"] || !email_otp_scope_current?(context)
    return false unless email_otp_binding_current?(context, contact, require_login_allowed: false)

    now = self.class.database_now
    deadline = context.fetch("verified_at") ? context.fetch("result_expires_at") : context.fetch("expires_at")
    parent = email_otp_parent
    active?(now: now) && admitted? && parent.present? && email_otp_parent_pending?(parent, now) &&
      Time.iso8601(deadline) > now
  end

  def cancel_email_otp_challenge!
    with_email_otp_parent_lock(refuse_unavailable: true) do |_parent, now|
      context = email_otp_context
      return false if context.nil? || !email_otp_scope_current?(context)
      return false if context.fetch("verified_at") || context["cancelled_at"]

      update!(email_otp_context: context.merge("cancelled_at" => now.utc.iso8601(6)))
      true
    end
  end

  # The mailer opts into the final delivery boundary. Owner, parent and continuity
  # locks serialize reissue/release/verification with the actual transport call.
  def with_email_otp_delivery!(generation:, code:, destination:)
    with_email_otp_parent_lock(refuse_unavailable: true) do |parent, _now|
      context = email_otp_context
      return false unless context && email_otp_scope_current?(context) && context.fetch("mode") == "real"
      return false if context["cancelled_at"]
      return false unless context.fetch("generation") == generation && context.fetch("verified_at").nil?

      contact = email_otp_contact_model.find_by(public_id: context.fetch("contact_ref"))
      return false if contact.nil?

      with_email_otp_contact_lock(contact) do |locked|
        now = self.class.database_now
        return false if expire_email_otp_local_parent!(parent, now)
        return false unless active?(now: now) && email_otp_parent_pending?(parent, now)
        return false unless email_otp_binding_current?(context, locked) && !locked.locked?
        return false unless Time.iso8601(context.fetch("expires_at")) > now &&
          context.fetch("destination_digest") == IdentifierBlindIndex.bidx_for_email(
            destination,
            realm: email_otp_surface,
          )
        return false unless ActiveSupport::SecurityUtils.secure_compare(
          context.fetch("code_digest"), AuthEmailOtpCodeDigest.for(context: context, code: code),
        )

        yield
        true
      end
    end
  end

  private

  def well_formed_email_otp_code?(code)
    code.is_a?(String) && code.valid_encoding? && code.match?(/\A[0-9]{6}\z/)
  end

  def verify_email_otp_comparison!(context, contact, code, now, parent)
    valid = contact.present? && ActiveSupport::SecurityUtils.secure_compare(
      context.fetch("code_digest"), AuthEmailOtpCodeDigest.for(context: context, code: code),
    )
    outcome = EmailOtpVerificationFailureBudget.new.verify!(
      surface: email_otp_surface.to_sym, purpose: :authentication, channel: :email,
      destination_digest: context.fetch("destination_digest"), valid: valid,
    )
    unless outcome == :verified
      contact.increment_attempts! if contact && !valid
      return email_otp_refusal(outcome)
    end

    updated = context.merge(
      "verified_at" => now.utc.iso8601(6),
      "result_expires_at" => [now + 60.seconds, expires_at, email_otp_parent_deadline(parent)].min.utc.iso8601(6),
    )
    update!(email_otp_context: updated)
    AuthEmailOtpVerificationResult.new(status: :verified, contact: contact)
  end

  def email_otp_binding_context(contact, digest)
    {
      "surface" => email_otp_surface,
      "purpose" => "authentication",
      "sid_digest" => sid_digest,
      "parent_kind" => local_sign_in_flow_ref.present? ? "local_sign_in" : "oidc",
      "parent_ref" => local_sign_in_flow_ref.presence || authorization_transaction_ref,
      "mode" => contact ? "real" : "fake",
      "contact_ref" => contact&.public_id,
      "owner_ref" => contact && email_otp_owner(contact).public_id,
      "destination_digest" => digest,
      "binding_fact" => contact&.binding_finalized_at&.utc&.iso8601(6),
    }
  end

  def email_otp_binding_current?(context, contact, require_login_allowed: true)
    return context.fetch("mode") == "fake" if contact.nil?

    contact.binding_effective? && (!require_login_allowed || email_otp_owner(contact).login_allowed?) &&
      context.fetch("contact_ref") == contact.public_id &&
      context.fetch("owner_ref") == email_otp_owner(contact).public_id &&
      context.fetch("destination_digest") == contact.address_digest &&
      context.fetch("binding_fact") == contact.binding_finalized_at.utc.iso8601(6)
  end

  def email_otp_scope_current?(context)
    context.fetch("surface") == email_otp_surface && context.fetch("purpose") == "authentication" &&
      context.fetch("sid_digest") == sid_digest &&
      context.fetch("parent_kind") == (local_sign_in_flow_ref.present? ? "local_sign_in" : "oidc") &&
      context.fetch("parent_ref") == (local_sign_in_flow_ref.presence || authorization_transaction_ref)
  end

  def email_otp_parent_deadline(parent)
    return parent.expires_at if local_sign_in_flow_ref.present?

    [parent.expires_at, parent.login_challenge_expires_at].min
  end

  def with_email_otp_contact_lock(contact)
    return yield(nil) if contact.nil?
    raise ArgumentError, "email Contact does not match Auth surface" unless contact.is_a?(email_otp_contact_model)

    owner = email_otp_owner(contact)
    raise AuthCeremonySession::InvalidTransition, "email Contact owner missing" if owner.nil?

    owner.with_lock { contact.with_lock { yield(contact) } }
  end

  def with_email_otp_parent_lock(refuse_unavailable: false)
    expired_local_parent = false
    result =
      self.class.writing_connection do
        parent = email_otp_parent
        return false if parent.nil? && refuse_unavailable

        raise AuthCeremonySession::InvalidTransition, "email authentication parent missing" if parent.nil?

        parent.with_lock do
          with_lock do
            now = self.class.database_now
            if expire_email_otp_local_parent!(parent, now)
              expired_local_parent = true
              next false
            end
            unless active?(now: now) && admitted? && !authentication_evidence_recorded? && email_otp_parent_pending?(
              parent, now,
            )
              return false if refuse_unavailable

              raise AuthCeremonySession::InvalidTransition, "email authentication ceremony unavailable"
            end

            yield(parent, now)
          end
        end
      end
    if expired_local_parent && !refuse_unavailable
      raise AuthCeremonySession::InvalidTransition, "email authentication ceremony unavailable"
    end

    result
  end

  def expire_email_otp_local_parent!(parent, now)
    return false unless local_sign_in_flow_ref.present? && parent.sign_in_primary_pending? && parent.expires_at <= now

    parent.expire_sign_in!
    true
  end

  def email_otp_parent
    if local_sign_in_flow_ref.present?
      case self
      when ClientAuthCeremonySession then ClientSignInFlow.find_by(public_id: local_sign_in_flow_ref)
      when VisitorAuthCeremonySession then VisitorSignInFlow.find_by(public_id: local_sign_in_flow_ref)
      else raise ArgumentError, "unsupported email authentication surface"
      end
    elsif authorization_transaction_ref.present?
      case self
      when ClientAuthCeremonySession
        ClientOidcAuthorizationTransaction.find_by(transaction_id: authorization_transaction_ref)
      when VisitorAuthCeremonySession
        VisitorOidcAuthorizationTransaction.find_by(transaction_id: authorization_transaction_ref)
      else raise ArgumentError, "unsupported email authentication surface"
      end
    end
  end

  def email_otp_parent_pending?(parent, now)
    return false if parent.expires_at <= now

    if local_sign_in_flow_ref.present?
      admission_purpose == "local_sign_in" && parent.sign_in_primary_pending? && parent.principal_id.nil?
    else
      admission_purpose == "authentication_handoff" && parent.status == "pending" &&
        !parent.login_challenge_expired?(now: now)
    end
  end

  def email_otp_surface
    case self
    when ClientAuthCeremonySession then "app"
    when VisitorAuthCeremonySession then "com"
    else raise ArgumentError, "unsupported email authentication surface"
    end
  end

  def email_otp_contact_model
    case self
    when ClientAuthCeremonySession then ClientEmail
    when VisitorAuthCeremonySession then VisitorEmail
    else raise ArgumentError, "unsupported email authentication surface"
    end
  end

  def email_otp_owner(contact)
    case contact
    when ClientEmail then contact.user
    when VisitorEmail then contact.visitor
    else raise ArgumentError, "unsupported email authentication Contact"
    end
  end

  def email_otp_refusal(status)
    AuthEmailOtpVerificationResult.new(status: status, contact: nil)
  end
end
