# typed: false
# frozen_string_literal: true

# Shared receiver checks for the Avatar authority API under /api/v0/avatar/:surface (R5-WU14,
# docs/architecture/avatar-authority-contract-proposal.md, approved 2026-10-17).
#
# Server-to-server from the Base Self-RP of the same realm: the caller proves itself with its
# private_key_jwt bound to the exact URL (no query string) and presents the actor's Access JWT.
# The owner re-resolves everything itself: the real actor from the token and the complete selected
# context from request identifiers. It matches that tuple against the actor's selectable candidates;
# the RP's selection is transport, never authority. Existing Avatar policy, ownership-period and
# membership checks then apply.
module AvatarAuthorityApiEndpoint
  extend ActiveSupport::Concern

  REALMS = {
    "app" => { surface: :app, client_id: "base-app-ww", resource_type: "client", grant: OpAppGrant },
    "org" => { surface: :org, client_id: "base-org-ww", resource_type: "operator", grant: OpOrgGrant },
  }.freeze

  private

  attr_reader :avatar_actor, :avatar_root

  def avatar_realm
    case self.class::AVATAR_SURFACE
    when "app" then REALMS.fetch("app")
    when "org" then REALMS.fetch("org")
    else raise ArgumentError, "unsupported Avatar API surface"
    end
  end

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
    unless auth.resource.login_allowed?
      return render(json: { error: "invalid_token" }, status: :unauthorized)
    end

    grant = realm.fetch(:grant).find_by(
      public_id: auth.payload["sid"],
      oidc_client_id: realm.fetch(:client_id),
    )
    return render(json: { error: "invalid_token" }, status: :unauthorized) unless grant&.active?

    @avatar_actor = auth.resource
    @avatar_root = grant.parent_token
    @avatar_access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid, resource: @avatar_actor, rp_session: grant, payload: auth.payload, security_context: nil,
    )
  end

  # Base APP and ORG selections are owned by their RP sessions. The owner treats every supplied
  # identifier as untrusted and resolves the complete tuple against this verified actor's real
  # candidates before installing it for the existing Avatar policies.
  def verify_avatar_persona!
    candidate = BaseSwitcherAuthority.new(
      surface: avatar_realm.fetch(:surface), principal: avatar_actor,
    ).candidate_for_public_ids(
      account_public_id: params[:persona],
      organization_public_id: params[:organization_public_id],
      organization_unit_public_id: params[:organization_unit_public_id],
      avatar_public_id: params[:avatar_public_id],
    )
    return render_forbidden unless candidate

    public_ids = candidate.fetch(:public)
    @avatar_switcher = BaseSwitcherAuthority.new(
      surface: avatar_realm.fetch(:surface), principal: avatar_actor, selection: public_ids,
    )
    Actor.install_context!(
      selection: Actor::SelectedContext.new(
        account_public_id: public_ids.fetch(:account_public_id),
        collective_public_id: public_ids.fetch(:organization_public_id),
        collective_unit_public_id: public_ids.fetch(:organization_unit_public_id),
        avatar_public_id: public_ids.fetch(:avatar_public_id),
      ),
    )
  end

  # Keep the OP transaction open while the domain writer rechecks and commits. The writer obtains
  # device, root and grant locks in refresh order; this wrapper does not pre-lock the root.
  def with_owner_step_up(scope)
    evidence = current_step_up_evidence
    return require_owner_step_up(scope, nil) unless evidence

    avatar_root.class.transaction { yield evidence }
  end

  # Read-only owner endpoints run on the read role, where SELECT FOR UPDATE is forbidden. They
  # keep the same owner-side proof check without locking because they do not authorize a mutation.
  def with_owner_step_up_read(scope, surface:)
    require_owner_step_up(scope, surface) { |evidence| yield evidence }
  end

  # OidcAccessTokenAuthenticator has verified this exact payload and the shared resolver binds its
  # event snapshot to the active grant, root, device, client, subject and authentication context.
  def current_step_up_evidence
    StepUpEvidenceResolver.call(
      access_state: @avatar_access_state,
      actor: avatar_actor,
      cell: RpCellBinding.for_client(avatar_realm.fetch(:client_id)),
    )
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

  def require_owner_step_up(scope, _surface)
    evidence = current_step_up_evidence
    unless evidence
      render json: { error: "step_up_required", scope: }, status: :forbidden
      return
    end

    yield evidence if block_given?
    true
  end
end
