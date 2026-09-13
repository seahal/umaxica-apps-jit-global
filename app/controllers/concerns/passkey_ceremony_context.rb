# typed: false
# frozen_string_literal: true

# Shared WebAuthn ceremony context for controllers: resolves the declared
# surface's relying-party config, issues and consumes surface/RP/origin/
# purpose/actor-bound one-time challenges, and serializes options for the
# browser. Controllers stay limited to HTTP flow; verification itself lives in
# Webauthn::RegistrationVerifier / Webauthn::AssertionVerifier.
module PasskeyCeremonyContext
  extend ActiveSupport::Concern

  include WebauthnSurfaceDeclarable

  private

  def passkey_challenge_store
    @passkey_challenge_store ||= Webauthn::ChallengeStore.new(session)
  end

  def passkey_actor_global_key(actor)
    return nil if actor.nil?

    "#{webauthn_surface.key}:#{actor.id}"
  end

  def passkey_actor_id_from(actor_global_key)
    return nil if actor_global_key.blank?

    prefix = "#{webauthn_surface.key}:"
    return nil unless actor_global_key.start_with?(prefix)

    Integer(actor_global_key.delete_prefix(prefix), exception: false)
  end

  # @return [Array(String, Hash)] challenge id and JSON-ready creation options
  def issue_passkey_registration_challenge(resource:, exclude_credentials: [])
    config = webauthn_relying_party_config
    options = Webauthn::RegistrationVerifier.options_for(
      config: config,
      user_id: resource.webauthn_user_handle,
      user_name: passkey_resource_display_name(resource),
      exclude_ids: webauthn_credential_ids(exclude_credentials),
    )

    challenge_id = passkey_challenge_store.issue!(
      challenge: options.challenge,
      purpose: :registration,
      surface: webauthn_surface.key,
      rp_id: config.rp_id,
      origin: config.origin,
      actor_global_key: passkey_actor_global_key(resource),
    )

    [challenge_id, Webauthn::OptionsSerializer.as_json(options)]
  end

  # Maps the challenge-store purpose to the UV policy purpose when the caller
  # does not name one explicitly (MFA passes uv_purpose: :mfa_challenge, since
  # its challenge purpose is :authentication).
  DEFAULT_UV_PURPOSES = {
    authentication: :direct_sign_in,
    emergency_sign_in: :emergency_sign_in,
    step_up: :ordinary_step_up,
  }.freeze

  # @return [Array(String, Hash)] challenge id and JSON-ready request options
  def issue_passkey_authentication_challenge(allow_credentials:, actor:, purpose: :authentication, uv_purpose: nil)
    config = webauthn_relying_party_config
    options = Webauthn::AssertionVerifier.options_for(
      config: config,
      allow_ids: webauthn_credential_ids(allow_credentials),
      purpose: uv_purpose || DEFAULT_UV_PURPOSES.fetch(purpose),
    )

    challenge_id = passkey_challenge_store.issue!(
      challenge: options.challenge,
      purpose: purpose,
      surface: webauthn_surface.key,
      rp_id: config.rp_id,
      origin: config.origin,
      actor_global_key: passkey_actor_global_key(actor),
    )

    [challenge_id, Webauthn::OptionsSerializer.as_json(options)]
  end

  # One-time consumption for ceremonies where the acting account is already
  # known (registration, step-up, MFA): every binding is verified, including
  # the actor.
  def consume_passkey_challenge!(challenge_id, purpose:, actor:)
    config = webauthn_relying_party_config
    passkey_challenge_store.consume!(
      challenge_id,
      purpose: purpose,
      surface: webauthn_surface.key,
      rp_id: config.rp_id,
      origin: config.origin,
      actor_global_key: passkey_actor_global_key(actor),
    )
  end

  # One-time consumption for identifier-first sign-in: returns the actor
  # binding recorded at issue time for the caller to enforce ownership.
  def consume_passkey_challenge_with_actor!(challenge_id, purpose: :authentication)
    config = webauthn_relying_party_config
    passkey_challenge_store.consume_with_actor!(
      challenge_id,
      purpose: purpose,
      surface: webauthn_surface.key,
      rp_id: config.rp_id,
      origin: config.origin,
    )
  end

  def discard_passkey_challenge(challenge_id)
    passkey_challenge_store.discard(challenge_id)
  end

  # Accepts passkey records or {id:} hashes and returns Base64URL credential ids.
  def webauthn_credential_ids(list)
    list.map do |item|
      item.respond_to?(:webauthn_id) ? item.webauthn_id : (item[:id] || item["id"])
    end
  end

  def passkey_resource_display_name(resource)
    if resource.respond_to?(:client_emails) && resource.client_emails.any?
      resource.client_emails.first.address
    elsif resource.respond_to?(:staff_emails) && resource.staff_emails.any?
      resource.staff_emails.first.address
    elsif resource.respond_to?(:public_id)
      resource.public_id
    else
      resource.id.to_s
    end
  end
end
