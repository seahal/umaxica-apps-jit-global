# typed: false
# frozen_string_literal: true

# Shared receiver checks for the Avatar authority API under /api/v0/avatar/:surface (R5-WU14,
# docs/architecture/avatar-authority-contract-proposal.md, approved 2026-10-17).
#
# Server-to-server from the Base Self-RP of the same realm: the caller proves itself with its
# private_key_jwt bound to the exact URL (no query string) and presents the actor's Access JWT.
# The owner re-resolves everything itself: the real actor from the token, the root (and its
# selected collective) from the token's grant `sid`, and the persona from the request, which must
# belong to that actor. Existing Avatar policy, ownership-period and membership checks then apply.
module AvatarAuthorityApiEndpoint
  extend ActiveSupport::Concern

  REALMS = {
    "app" => { client_id: "base-app-ww", resource_type: "client", grant: "OpAppGrant" },
    "com" => { client_id: "base-com-ww", resource_type: "visitor", grant: "OpComGrant" },
    "org" => { client_id: "base-org-ww", resource_type: "operator", grant: "OpOrgGrant" },
  }.freeze

  private

  attr_reader :avatar_actor, :avatar_root

  def avatar_realm = REALMS.fetch(self.class.const_get(:AVATAR_SURFACE, false))

  def authenticate_avatar_caller!
    response.headers["Cache-Control"] = "no-store"
    realm = avatar_realm
    unless OidcClientRegistry.authenticate_assertion(
      realm.fetch(:client_id), request.headers["X-Client-Assertion"].to_s,
      token_url: "#{request.base_url}#{request.path}",
    )
      return render(json: { error: "invalid_client" }, status: :unauthorized)
    end

    auth = OidcAccessTokenAuthenticator.call(
      access_token: request.authorization.to_s.delete_prefix("Bearer "), resource_type: realm.fetch(:resource_type),
      host: request.host, authorization_scheme: "Bearer",
    )
    unless auth.success? && auth.payload["client_id"] == realm.fetch(:client_id)
      return render(json: { error: "invalid_token" }, status: :unauthorized)
    end

    grant = realm.fetch(:grant).constantize.find_by(
      public_id: auth.payload["sid"],
      oidc_client_id: realm.fetch(:client_id),
    )
    return render(json: { error: "invalid_token" }, status: :unauthorized) unless grant&.active?

    @avatar_actor = auth.resource
    @avatar_root = grant.parent_token
  end

  # The persona field must equal the selection recorded on the actor's own root; the Actor context
  # (selection, tld) the existing Avatar policy reads is then installed from that root, exactly as
  # for a Base page (ActorSupport#set_current_actor via current_resource/current_session).
  def verify_avatar_persona!
    persona = params[:persona].to_s
    return if persona.present? && persona == avatar_root.try(:selected_account_public_id).to_s

    render_forbidden
  end

  # High-risk Avatar actions re-check the actor's Step-Up proof here, at the owner, under the root
  # row lock (one.md 7.5). The requirement mirrors VerificationBase#step_up_requirement for this
  # surface. When it is unmet the RP is told to run the Step-Up ceremony; nothing is written.
  def with_owner_step_up(scope)
    avatar_root.with_lock do
      surface = self.class.const_get(:AVATAR_SURFACE, false)
      requirement = StepUpRequirement.new(
        scope:, step_up_required: true,
        allowed_methods: avatar_actor.is_a?(Operator) ? [:passkey] : %i(email_otp passkey totp),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, session_binding: avatar_root.public_id,
        token_binding: avatar_root.public_id, ttl: VerificationBase::STEP_UP_TTL, purpose: "step_up",
        audience: "step_up:#{surface}", require_session_binding: true, actor_ref: avatar_actor.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      unless StepUpResolver.call(token: avatar_root, requirement:).satisfied?
        render json: { error: "step_up_required", scope: }, status: :forbidden
        return
      end

      yield requirement
    end
  end

  def current_resource = avatar_actor

  def current_session = avatar_root

  def avatar_switcher
    @avatar_switcher ||= BaseSwitcherAuthority.new(
      surface: self.class.const_get(:AVATAR_SURFACE, false).to_sym, principal: avatar_actor, session: avatar_root,
    )
  end

  def render_forbidden = render(json: { error: "forbidden" }, status: :forbidden)

  # A denial at the locked write, distinct from a policy refusal, so the RP keeps its 403 answer.
  def render_owner_denied = render(json: { error: "owner_denied" }, status: :forbidden)

  def render_not_found = render(json: { error: "not_found" }, status: :not_found)

  def render_bad_request = render(json: { error: "bad_request" }, status: :bad_request)
end
