# frozen_string_literal: true

require "test_helper"

class BaseZenithIdentityResolverTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    [ClientStatus, ClientMfaStatus, ClientVisibility,
     OperatorStatus, OperatorMfaStatus, OperatorVisibility,].each(&:ensure_defaults!)
    ClientSecurityMode.find_or_create_by!(id: ClientSecurityMode::NORMAL)
    ClientSecurityMode.find_or_create_by!(id: ClientSecurityMode::ADVANCED)
    OperatorSecurityMode.find_or_create_by!(id: OperatorSecurityMode::NORMAL)
    OperatorSecurityMode.find_or_create_by!(id: OperatorSecurityMode::ADVANCED)
  end

  test "Base APP resolves the canonical Client from the verified base-cell identity" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    state = authenticated_state(surface: :app, actor:)

    resolved = BaseZenithIdentityResolver.call(access_state: state, surface: :app)

    assert_instance_of Client, resolved
    assert_equal actor.public_id, resolved.public_id
    assert_not_same state.resource, resolved
  end

  test "Base ORG resolves the canonical Operator from the verified base-cell identity" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    state = authenticated_state(surface: :org, actor:)

    resolved = BaseZenithIdentityResolver.call(access_state: state, surface: :org)

    assert_instance_of Operator, resolved
    assert_equal actor.public_id, resolved.public_id
    assert_not_same state.resource, resolved
  end

  test "a claimed subject changed after local authentication is refused" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    state = authenticated_state(surface: :app, actor:)
    mismatched = state.with(payload: state.payload.merge("sub" => "cli_someone-else"))

    assert_raises(ActiveRecord::RecordNotFound) do
      BaseZenithIdentityResolver.call(access_state: mismatched, surface: :app)
    end
  end

  test "a local identity from another RP cell is refused" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    cell = RpCellBinding.fetch("rp_core_app")
    subject = OidcSubject.for(actor, resource_type: "client")
    enrollment = RpCallbackCommitter.call(
      cell:, issuer: OidcIssuer.for_resource_type("client"), subject:, sid: SecureRandom.uuid,
      absolute_expires_at: 1.hour.from_now,
    )
    state = authenticated_state_for_enrollment(
      cell:, enrollment:, subject:, issuer: OidcIssuer.for_resource_type("client"),
    )

    assert_raises(ActiveRecord::RecordNotFound) do
      BaseZenithIdentityResolver.call(access_state: state, surface: :app)
    end
  end

  test "a suspended canonical account is refused after its identity was authenticated" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    state = authenticated_state(surface: :app, actor:)
    actor.update!(deactivated_at: Time.current)

    assert_raises(ActiveRecord::RecordNotFound) do
      BaseZenithIdentityResolver.call(access_state: state, surface: :app)
    end
  end

  test "an unsupported surface or unauthenticated state is refused" do
    assert_raises(KeyError) do
      BaseZenithIdentityResolver.call(access_state: nil, surface: :core)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      BaseZenithIdentityResolver.call(
        access_state: BrowserRpAuthentication::AccessState.new(
          status: :missing, resource: nil, rp_session: nil, payload: nil, security_context: nil,
        ),
        surface: :app,
      )
    end
  end

  private

  def authenticated_state(surface:, actor:)
    configuration = BaseZenithIdentityResolver::SURFACES.fetch(surface)
    resource_type = configuration.fetch(:resource_type)
    cell = configuration.fetch(:cell)
    issuer = OidcIssuer.for_resource_type(resource_type)
    subject = OidcSubject.for(actor, resource_type:)
    enrollment = RpCallbackCommitter.call(
      cell:, issuer:, subject:, sid: SecureRandom.uuid, absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    authenticated_state_for_enrollment(cell:, enrollment:, subject:, issuer:)
  end

  def authenticated_state_for_enrollment(cell:, enrollment:, subject:, issuer:)
    anchor = enrollment.session.op_session_binding
    BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: enrollment.principal,
      rp_session: enrollment.session,
      payload: {
        "iss" => issuer,
        "aud" => [cell.client_id],
        "sub" => subject,
        "sid" => anchor.sid,
        "client_id" => cell.client_id,
      },
      security_context: nil,
    )
  end
end
