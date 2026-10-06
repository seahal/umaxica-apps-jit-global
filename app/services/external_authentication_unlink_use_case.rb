# typed: false
# frozen_string_literal: true

class ExternalAuthenticationUnlinkUseCase
  def self.call(...)
    new(...).call
  end

  def initialize(provider:, user:)
    @provider = SocialIdentifiable.normalize_provider(provider)
    @user = user
  end

  def call
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in") unless user

    repository = ExternalAuthentication::IdentityRepositoryFactory.current.build(provider)
    identity = repository.find_for_user(user)
    return ExternalAuthentication::UnlinkResult.new(status: :already_unlinked, provider: provider) unless identity

    AppPrincipalRecord.transaction do
      user.lock!
      if identity.active? && !AuthMethodGuard.can_remove_external_identity?(user, identity)
        raise SocialAuth::LastIdentityError.new("errors.social_auth.insufficient_login_methods")
      end

      record_audit!(identity)
      repository.destroy!(identity)
      retire_social_ceremony_evidence!(identity)
    end
    Rails.logger.info(JitLogEvent.format("social_auth.unlinked", user_id: user.id, provider: provider))
    ExternalAuthentication::UnlinkResult.new(status: :unlinked, provider: provider)
  end

  private

  attr_reader :provider, :user

  def record_audit!(identity)
    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicleEvent.find_or_create_by!(id: ClientChronicleEvent::SOCIAL_UNLINKED)
      ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
    end
    ClientChronicle.create!(
      actor_type: "Client",
      actor_id: user.id,
      event_id: ClientChronicleEvent::SOCIAL_UNLINKED,
      level_id: ClientChronicleLevel::NOTHING,
      subject_id: user.id.to_s,
      subject_type: "Client",
      occurred_at: Time.current,
      context: {
        auth_method: "social",
        provider: provider,
        social_identity_type: identity.class.name,
      },
    )
  end

  def retire_social_ceremony_evidence!(identity)
    subject_digest = IdentitySocialCeremonyContract.provider_subject_digest(
      provider: identity.provider,
      subject: identity.subject,
    )
    AppTicketRecord.connected_to(role: :writing) do
      ClientSocialCeremonyTransaction.transaction do
        transactions = ClientSocialCeremonyTransaction.lock.where(
          actor_ref: user.public_id,
          provider: identity.provider,
          provider_subject_digest: subject_digest,
          status: SocialCeremonyTransactionable::STATUS_PENDING,
        )
        ids = transactions.pluck(:transaction_id)
        transactions.update_all(
          status: SocialCeremonyTransactionable::STATUS_CONSUMED,
          consumed_at: ClientSocialCeremonyTransaction.database_now,
          updated_at: ClientSocialCeremonyTransaction.database_now,
        )
        IdentitySocialCeremonyCandidate.where(transaction_id: ids).update_all(
          consumed_at: IdentitySocialCeremonyCandidate.database_now,
          updated_at: IdentitySocialCeremonyCandidate.database_now,
        ) if ids.any?
      end
    end
  end
end
