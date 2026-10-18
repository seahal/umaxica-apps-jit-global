# typed: false
# frozen_string_literal: true

# Surface-neutral entry point for external-identity ceremony start.
#
# The ceremony is POST only. The press of an in-application provider button
# supplies the CSRF token the OmniAuth request phase requires, and the handoff is
# a 307 so that same POST, method and body intact, reaches the request phase
# (OmniAuth.config.allowed_request_methods = [:post]).
#
# There is no GET entry on purpose: a GET carries no token, so a link that
# started a ceremony would be login CSRF (CVE-2015-9284). People choose their
# provider on the sign-in or sign-up page.
#
# This concern holds only what every surface shares: the provider allow-list
# check, the provider availability gate, and the handoff. Everything that
# differs per surface is a hook. The three required hooks raise rather than
# defaulting, because a surface that silently inherited another surface's
# provider list, gate surface, or redirect target would be a cross-surface
# leak (.agents/harnesses/rules/project/surfaces.mdc).
#
# Surface-local extensions:
# - app: AppSocialCeremonyEntry adds sign-up entry detection, ceremony grants,
#   the link/step-up intents, and the ClientSignUpFlow issuance.
# - org: Auth::Org::Social::SessionsController implements the required hooks
#   only; the org surface has no social sign-up at all, because Entra sign-in
#   performs no JIT provisioning (adr/org-entra-id-sign-in-boundary.md).
module SocialCeremonyEntry
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include ExternalAuthenticationEndpoint
  end

  private

  # --- Required hooks -------------------------------------------------------

  # @return [String] surface name passed to the provider policy/availability
  #   gate, e.g. "app" or "org".
  def social_ceremony_surface
    raise NotImplementedError, "#{self.class} must implement #social_ceremony_surface"
  end

  # @return [Array<String>] providers this surface may start a ceremony for.
  def social_ceremony_providers
    raise NotImplementedError, "#{self.class} must implement #social_ceremony_providers"
  end

  # @return [String] path to redirect to when the ceremony cannot start.
  def social_ceremony_abort_path
    raise NotImplementedError, "#{self.class} must implement #social_ceremony_abort_path"
  end

  # --- Optional hooks -------------------------------------------------------

  # Operation name for the provider policy and availability gate. Surfaces
  # with a sign-up ceremony override this to distinguish signup from login.
  def social_ceremony_operation(intent)
    intent.to_s.presence || "login"
  end

  # Ceremony state a surface needs before handing off (intent session state,
  # replay grants, sign-up flow records). Called with `intent:` and `provider:`;
  # the default needs neither, so it accepts and discards them. Return false to
  # abort the handoff; the hook is responsible for having issued its own
  # response in that case.
  def prepare_surface_ceremony_state!(**)
    true
  end

  # --- Algorithm ------------------------------------------------------------

  # OmniAuth request-phase path for a provider, from the registry rather than a
  # per-surface literal, so the path a surface hands off to and the path the
  # middleware mounts cannot drift apart. The app surface overrides this in
  # SocialAuth, which also accepts a `state:` argument.
  def social_ceremony_request_path(provider)
    ExternalAuthentication::ProviderRegistry.fetch(
      SocialIdentifiable.normalize_provider(provider),
    ).request_path
  end

  # Prepares the ceremony, then hands the request on with a 307.
  def handoff_social_ceremony!
    return unless prepare_social_ceremony!

    redirect_to(
      social_ceremony_request_path(params[:provider]),
      status: :temporary_redirect,
    )
  rescue SocialAuth::BaseError => e
    handle_social_auth_error(e)
  end

  # @return [Boolean] false when the request was redirected instead.
  def prepare_social_ceremony!
    provider = params[:provider]
    intent = params[:intent] || "login"

    unless social_ceremony_providers.include?(provider)
      redirect_to(social_ceremony_abort_path)
      return false
    end

    # Gating the *start* is what bounds the callback's `:draining` state:
    # draining exists to let ceremonies issued before a kill switch was flipped
    # finish, which is only bounded if no new ceremony can start. An operation
    # outside ProviderSurfacePolicy (a forged `intent`) fails the first check
    # and short-circuits before the adapter sees it.
    operation = social_ceremony_operation(intent)
    unless external_authentication_allowed?(
      surface: social_ceremony_surface, provider: provider,
      operation: operation,
    ) &&
        external_authentication_start_available?(provider: provider, operation: operation, context: {})
      redirect_to(social_ceremony_abort_path, status: :see_other)
      return false
    end

    prepare_surface_ceremony_state!(intent: intent, provider: provider)
  end
end
