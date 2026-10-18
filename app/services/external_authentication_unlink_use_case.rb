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
    result =
      AppPrincipalRecord.transaction do
        user.lock!
        identity = repository.find_for_user(user)
        next ExternalAuthentication::UnlinkResult.new(status: :already_unlinked, provider: provider) unless identity

        ClientExternalIdentity.with_subject_lock(
          provider: identity.provider, issuer: identity.issuer, subject: identity.subject,
        ) do
          if identity.active? && !AuthMethodGuard.can_remove_external_identity?(user, identity)
            raise SocialAuth::LastIdentityError.new("errors.social_auth.insufficient_login_methods")
          end

          repository.destroy!(identity)
          ClientSocialAuditOutbox.record!(identity: identity, owner: user, event_name: "unlinked")
          retire_social_ceremony_evidence!(identity)
        end
        ExternalAuthentication::UnlinkResult.new(status: :unlinked, provider: provider)
      end
    Rails.logger.info(JitLogEvent.format("social_auth.unlinked", user_id: user.id, provider: provider)) if
      result.status == :unlinked
    result
  end

  private

  attr_reader :provider, :user

  def retire_social_ceremony_evidence!(identity)
    subject_digest = IdentitySocialCeremonyContract.provider_subject_digest(
      provider: identity.provider,
      subject: identity.subject,
    )
    OpBaseAppRecord.connected_to(role: :writing) do
      ClientSocialCeremonyTransaction.transaction do
        transactions = ClientSocialCeremonyTransaction.lock.where(
          actor_ref: user.public_id,
          provider: identity.provider,
          provider_subject_digest: [subject_digest, nil],
          status: SocialCeremonyTransactionable::STATUS_PENDING,
        )
        ids = transactions.pluck(:transaction_id)
        # Unlink invalidates unfinished evidence; it cannot fabricate a successful ceremony result.
        transactions.order(:id).each do |transaction|
          transaction.expire!
        end
        IdentitySocialCeremonyCandidate.where(transaction_id: ids).lock.order(:id).each do |candidate|
          candidate.expire!
        end
      end
    end
  end
end
