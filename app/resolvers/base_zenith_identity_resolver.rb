# typed: false
# frozen_string_literal: true

# Resolves the canonical Base account from the identity already authenticated by a Base RP cell.
# The local principal is only an RP credential; its numeric id never crosses into Zenith.
class BaseZenithIdentityResolver
  class DependencyUnavailable < StandardError; end

  SURFACES = {
    app: {
      cell: RpCellBinding.fetch("rp_base_app"),
      cell_record: RpBaseAppRecord,
      session_class: RpBaseAppSession,
      identity_binding_class: RpBaseAppIdentityBinding,
      principal_class: RpBaseAppPrincipal,
      actor_class: Client,
      resource_type: "client",
    }.freeze,
    org: {
      cell: RpCellBinding.fetch("rp_base_org"),
      cell_record: RpBaseOrgRecord,
      session_class: RpBaseOrgSession,
      identity_binding_class: RpBaseOrgIdentityBinding,
      principal_class: RpBaseOrgPrincipal,
      actor_class: Operator,
      resource_type: "operator",
    }.freeze,
  }.freeze

  class << self
    public

    def call(...) = new(...).call
  end

  def initialize(access_state:, surface:)
    @access_state = access_state
    @surface = surface.to_sym
  end

  public

  def call
    configuration = SURFACES.fetch(surface)
    validate_access_state!(configuration)
    claims = access_state.payload
    session = reload_session!(configuration, access_state.rp_session)
    identity_binding = session.op_session_binding&.identity_binding
    validate_binding!(configuration, claims, session, identity_binding)

    resolve_actor!(configuration, identity_binding.subject)
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionTimeoutError => e
    raise DependencyUnavailable, "Base identity store is unavailable", cause: e
  end

  private

  attr_reader :access_state, :surface

  def validate_access_state!(configuration)
    unless access_state.is_a?(BrowserRpAuthentication::AccessState) && access_state.status == :valid
      refuse_identity!
    end

    unless access_state.rp_session.instance_of?(configuration.fetch(:session_class)) &&
        access_state.resource.instance_of?(configuration.fetch(:principal_class)) &&
        access_state.payload.is_a?(Hash)
      refuse_identity!
    end
  end

  def reload_session!(configuration, authenticated_session)
    session_class = configuration.fetch(:session_class)
    cell_record = configuration.fetch(:cell_record)

    cell_record.connected_to(role: :writing) do
      session_class.includes(op_session_binding: { identity_binding: :principal })
        .find_by!(id: authenticated_session.id, public_id: authenticated_session.public_id)
    end
  end

  def validate_binding!(configuration, claims, session, identity_binding)
    cell = configuration.fetch(:cell)
    binding_class = configuration.fetch(:identity_binding_class)
    anchor = session.op_session_binding

    unless identity_binding.instance_of?(binding_class) &&
        identity_binding.principal_id == access_state.resource.id &&
        session.active? && anchor && anchor.revoked_at.nil? &&
        exact_string?(identity_binding.issuer, OidcIssuer.for_resource_type(configuration.fetch(:resource_type))) &&
        identity_binding.realm == cell.realm &&
        identity_binding.client_id == cell.client_id &&
        exact_string?(identity_binding.subject, claim(claims, "sub")) &&
        exact_string?(anchor.issuer, claim(claims, "iss")) &&
        exact_string?(anchor.sid, claim(claims, "sid")) &&
        exact_string?(cell.client_id, claim(claims, "client_id")) &&
        claims["aud"] == [cell.client_id] &&
        exact_string?(identity_binding.issuer, claim(claims, "iss"))
      refuse_identity!
    end

    refuse_identity! unless access_state.resource.disabled_at.nil?
  end

  def resolve_actor!(configuration, subject)
    resource_type = configuration.fetch(:resource_type)
    public_id = OidcSubject.public_id_from(subject, resource_type:)
    refuse_identity! if public_id.blank?

    actor_class = configuration.fetch(:actor_class)
    actor_class.connection_class_for_self.connected_to(role: :writing) do
      actor_class.uncached do
        actor = actor_class.find_by(public_id:)
        refuse_identity! unless actor&.login_allowed? && !actor.deactivated?
        refuse_identity! unless secure_string_equal?(OidcSubject.for(actor, resource_type:), subject)

        actor
      end
    end
  end

  def claim(claims, name)
    value = claims[name]
    value if value.is_a?(String) && value.present?
  end

  def exact_string?(value, expected)
    value.is_a?(String) && expected.is_a?(String) && secure_string_equal?(value, expected)
  end

  def secure_string_equal?(left, right)
    left.bytesize == right.bytesize && ActiveSupport::SecurityUtils.secure_compare(left, right)
  end

  def refuse_identity!
    raise ActiveRecord::RecordNotFound, "Base identity could not be resolved"
  end
end
