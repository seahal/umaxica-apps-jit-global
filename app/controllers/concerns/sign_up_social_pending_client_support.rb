# typed: false
# frozen_string_literal: true

# adr/sign-up-finalization-in-auth.md (WU-05d): Google and Apple sign-up create their pending Client
# in Auth, after the provider evidence is verified and the confirmation passed its ceremony-bound
# Turnstile. The Client has no External Identity until the shared Finalization writes it.
module SignUpSocialPendingClientSupport
  private

  # P1-P3: one pending Client per Flow, recorded on the Flow under its lock. A repeated confirmation
  # of the same Flow keeps the Client it already has.
  def bind_social_pending_client!
    sign_up_ticket_record_class.connected_to(role: :writing) do
      @sign_up_ticket.with_cycle_lock do
        @sign_up_ticket.reload
        @sign_up_ticket.require_active_cycle!
        next if @sign_up_ticket.principal_id.present?

        social_signup_candidate!
        client =
          AppZenithRecord.connected_to(role: :writing) do
            Client.create!(
              status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
              security_mode_id: ClientSecurityMode::NORMAL,
              visibility_id: ClientVisibility::STAFF,
              mfa_status_id: ClientMfaStatus::UNCONFIGURED,
            )
          end
        @sign_up_ticket.update!(principal_id: client.id, pending_contact_type: "social_identity")
      end
    end
  end

  # F3: under the Flow lock, consume the Candidate once, then write the External Identity and the
  # registered status in one principal transaction.
  def finalize_social_sign_up_identity!(actor)
    candidate = social_signup_candidate!
    consumed = IdentitySocialCeremonyCandidateStore.consume!(social_signup_evidence.fetch("candidate_ref"))
    raise IdentitySocialCeremonyContract::Error, "candidate changed" unless consumed.digest == candidate.digest

    callback_result = consumed.callback_result
    identity =
      AppZenithRecord.connected_to(role: :writing) do
        SocialAuthSignupFinalizer.call(
          user: actor,
          principal: callback_result.principal,
          credential_candidate: callback_result.credential_candidate,
          ceremony_started_at: @sign_up_ticket.issued_at,
        ).fetch(:identity)
      end
    @sign_up_ticket.update!(pending_contact_id: identity.id)
  end

  def social_signup_evidence
    value = @sign_up_ticket&.completed_requirements&.fetch("social_signup", nil)
    raise IdentitySocialCeremonyContract::Error, "social signup evidence is required" unless value.is_a?(Hash)

    value
  end

  # C2: the Candidate must still be the one this Flow's callback stored, for this Admission.
  def social_signup_candidate!
    evidence = social_signup_evidence
    candidate = IdentitySocialCeremonyCandidateStore.fetch!(evidence.fetch("candidate_ref"))
    checks = {
      "candidate digest mismatch" => candidate.digest.to_s == evidence.fetch("candidate_digest").to_s,
      "candidate surface mismatch" => candidate.surface.to_s == "app",
      "candidate actor mismatch" => candidate.actor_ref.to_s == @sign_up_ticket.public_id.to_s,
      "candidate session mismatch" => candidate.session_ref.to_s == auth_social_admission_binding!.entry_ref.to_s,
      "candidate transaction mismatch" =>
        candidate.transaction_id.to_s == (evidence["grant_transaction_id"].presence || @sign_up_ticket.public_id).to_s,
      "candidate operation mismatch" => candidate.operation.to_s == "signup",
    }
    checks.each { |message, ok| raise IdentitySocialCeremonyContract::Error, message unless ok }

    provider = SocialIdentifiable.normalize_provider(candidate.provider)
    unless provider == @sign_up_ticket.social_provider && provider == evidence.fetch("provider") &&
        social_signup_uid_digest(provider:, uid: candidate.callback_result.principal.subject) ==
            evidence.fetch("uid_digest")
      raise IdentitySocialCeremonyContract::Error, "candidate provider evidence mismatch"
    end

    candidate
  end

  def social_signup_uid_digest(provider:, uid:)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, [provider, uid].map(&:to_s).join(":"))
  end
end
