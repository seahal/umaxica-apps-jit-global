# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class ClientExternalIdentityRepositoryAdapter
    include ExternalIdentityRepositoryPort

    attr_reader :provider

    def initialize(provider:)
      @provider = ProviderRegistry.fetch(provider).provider.freeze
    end

    def find_by_subject(subject, lock:)
      scope = ClientExternalIdentity.effective_binding.where(
        provider: provider, issuer: issuer, subject: subject.to_s, state: "active",
      )
      scope = scope.lock if lock
      scope.first
    end

    def find_by_subject_for_link(subject, lock:)
      scope = ClientExternalIdentity.effective_binding.where(
        provider: provider, issuer: issuer, subject: subject.to_s,
      )
      scope = scope.lock if lock
      scope.first
    end

    def find_for_user(user)
      user.client_external_identities.effective_binding.find_by(provider: provider, state: "active")
    end

    def find_for_user_for_link(user)
      user.client_external_identities.effective_binding.find_by(provider: provider)
    end

    def build_for_user(user:, principal:, credential_candidate:)
      validate_principal!(principal)
      identity = ClientExternalIdentity.new(
        client: user,
        provider: provider,
        issuer: principal.issuer,
        subject: principal.subject,
        audience: principal.audience,
        verification_authority: principal.verification_authority,
        verified_at: principal.verified_at,
      )
      validate_candidate!(credential_candidate)
      identity
    end

    def refresh_credentials!(identity, principal:, credential_candidate:)
      validate_identity!(identity)
      validate_principal!(principal)
      identity.assign_attributes(
        issuer: principal.issuer,
        subject: principal.subject,
        audience: principal.audience,
        verification_authority: principal.verification_authority,
        verified_at: principal.verified_at,
        last_authenticated_at: Time.current,
      )
      validate_candidate!(credential_candidate)
      identity.save!
      identity
    end

    def assign_to_user(identity, user)
      validate_identity!(identity)
      identity.client = user
      identity
    end

    def activate!(identity)
      validate_identity!(identity)
      raise ArgumentError, "released external identity cannot be reactivated" if identity.released_at.present?
      raise ArgumentError, "account-deleted identity cannot be reactivated" if identity.state == "account_deleted"

      identity.update!(state: "active")
      identity
    end

    def destroy!(identity)
      validate_identity!(identity)
      identity.release!
    end

    def ensure_active_status!
      true
    end

    def refresh_token_for(identity)
      validate_identity!(identity)
      nil
    end

    private

    def issuer
      ProviderRegistry.fetch(provider).issuer
    end

    def validate_principal!(principal)
      return if principal.is_a?(VerifiedPrincipal) && principal.provider == provider && principal.issuer == issuer

      raise ArgumentError, "principal does not match repository provider"
    end

    def validate_identity!(identity)
      return if identity.is_a?(ClientExternalIdentity) && identity.provider == provider

      raise ArgumentError, "identity does not match repository provider"
    end

    def validate_candidate!(candidate)
      return if candidate.nil?

      raise ArgumentError, "provider credential candidate must be absent"
    end
  end
end
