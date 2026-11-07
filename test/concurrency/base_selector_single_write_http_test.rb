# frozen_string_literal: true

require "test_helper"
require "timeout"

class BaseSelectorSingleWriteHttpTest < ActionDispatch::IntegrationTest
  include DatabaseSelectorPrimary

  self.use_transactional_tests = false
  self.fixture_table_names = []

  teardown do
    @workers&.each { |worker| worker.join(10) }
    cleanup_browser_session!
    cleanup_source_session!
    cleanup_actor_graph!
  ensure
    restore_database_selector_delay!
  end

  test "APP concurrent selector updates preserve the first committed choice" do
    assert exercise_selector_race!(surface: :app)
  end

  test "ORG concurrent selector updates preserve the first committed choice" do
    assert exercise_selector_race!(surface: :org)
  end

  private

  def exercise_selector_race!(surface:)
    keep_reads_on_primary!
    @surface = surface
    @host = ENV.fetch((surface == :app) ? "PUBLIC_BASE_SERVICE_URL" : "PUBLIC_BASE_STAFF_URL")
    create_principal!
    create_second_unit_candidate!
    first, later = two_selector_candidates!
    headers = authenticated_headers
    @rp_session = rp_session_for(headers)

    assert_unselected_session!
    url = warm_selector!

    assert_first_commit_wins!(first, later, headers, url)
    true
  end

  def two_selector_candidates!
    candidates = BaseSelectorAuthority.new(surface: @surface, principal: @principal, session: nil)
      .selectable_candidates

    assert_equal 2, candidates.size

    candidates
  end

  def assert_unselected_session!
    assert_not @rp_session.selected_actor_context?
    return unless @surface == :org

    assert_equal 2, OperatorPasskey.where(
      staff_id: @principal.id, status_id: OperatorPasskeyStatus::ACTIVE,
    ).count
  end

  def warm_selector!
    url = selector_url
    get(url, headers: authenticated_headers, as: :json)

    assert_response :success
    assert_equal "selection_required", response.parsed_body.fetch("status")

    url
  end

  def assert_first_commit_wins!(first, later, headers, url)
    pids, results = run_concurrent_updates(first, later, headers, url)

    assert_equal 2, pids.uniq.size
    assert_single_selection_wins!(results)
  end

  def run_concurrent_updates(first, later, headers, url)
    @workers = []
    ready = Queue.new
    release = Queue.new
    first_browser, second_browser = [open_session, open_session]
    [first_browser, second_browser].each do |browser|
      browser.host!(@host)
      browser.https!
    end

    @workers << start_update(first_browser, first, headers, url, ready, release)
    @workers << start_update(second_browser, later, headers, url, ready, release)
    pids = 2.times.map { Timeout.timeout(10) { ready.pop } }
    2.times { release << true }

    results = @workers.map { |worker| Timeout.timeout(15) { worker.value } }

    results.each { |result| raise result if result.is_a?(Exception) }

    [pids, results]
  ensure
    release << true if release
    @workers&.each { |worker| worker.join(10) }
  end

  def assert_single_selection_wins!(results)
    statuses = results.map { |result| result.fetch(:status) }

    assert_equal(
      { 200 => 1, 409 => 1 }, statuses.tally,
      results.map { |result| response_summary(result) }.inspect,
    )
    winner = results.find { |result| result.fetch(:status) == 200 }
    loser = results.find { |result| result.fetch(:status) == 409 }

    assert_equal "selected", winner.fetch(:body).fetch("status")
    assert_equal "already_selected", loser.fetch(:body).fetch("status")
    assert_persisted_winner!(winner)
  end

  def assert_persisted_winner!(winner)
    assert_equal expected_selection(winner.fetch(:candidate)), persisted_selection
    assert_equal 1, selection_model.where(rp_session_id: @rp_session.id).count
  end

  def create_principal!
    if @surface == :app
      [ClientStatus, ClientVisibility, ClientMfaStatus].each(&:ensure_defaults!)
      ClientSecurityMode.insert_missing_fixed_ids!(ClientSecurityMode::DEFAULTS)
      ensure_token_references!(ClientTokenKind, ClientTokenStatus, ClientTokenBindingMethod, ClientTokenDbscStatus)
      @principal = Client.create!(status_id: ClientStatus::ACTIVE, security_mode_id: ClientSecurityMode::NORMAL)
      @root_token = ClientToken.create!(
        user: @principal, authentication_epoch: @principal.authentication_epoch,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      )
      @transaction_ids_before = ClientOidcAuthorizationTransaction.pluck(:id)
    else
      [OperatorStatus, OperatorVisibility].each(&:ensure_defaults!)
      OperatorPasskeyStatus.find_or_create_by!(id: OperatorPasskeyStatus::ACTIVE)
      OperatorSecurityMode.insert_missing_fixed_ids!(OperatorSecurityMode::DEFAULTS)
      ensure_token_references!(
        OperatorTokenKind, OperatorTokenStatus, OperatorTokenBindingMethod,
        OperatorTokenDbscStatus,
      )
      @principal = Operator.create!(
        status_id: OperatorStatus::ACTIVE, security_mode_id: OperatorSecurityMode::ADVANCED,
        visibility_id: OperatorVisibility::STAFF,
      )
      @root_token = OperatorToken.create!(
        staff: @principal, authentication_epoch: @principal.authentication_epoch,
        staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      )
      OperatorPasskeyTestSupport.give_two_active_passkeys!(@principal)
      @transaction_ids_before = OperatorOidcAuthorizationTransaction.pluck(:id)
    end
  end

  def authenticated_headers
    if @surface == :app
      as_user_headers(
        @principal, host: @host, session_public_id: @root_token.public_id,
                    select_available_app_persona: false,
      )
    else
      as_staff_headers(@principal, host: @host, session_public_id: @root_token.public_id)
    end
  end

  def create_second_unit_candidate!
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: @surface, principal: @principal)
    config = AcmeSelector.config_for(@surface)
    config.membership_kind_class.ensure_defaults!
    config.membership_state_class.ensure_defaults!
    create_second_unit!(config)
    create_second_membership!(config)
  end

  def create_second_unit!(config)
    attributes = { name: "Concurrent" }
    attributes[config.unit_collective_association] = @bootstrap.collective
    @second_unit = config.unit_class.create!(**attributes)
  end

  def create_second_membership!(config)
    attributes = {
      membership_kind_id: config.membership_kind_class::MEMBER,
      membership_state_id: config.membership_state_class::ACTIVE,
      primary: false,
      metadata: {},
      starts_at: Time.current,
    }
    attributes[config.membership_account_association] = @bootstrap.account
    attributes[config.membership_collective_association] = @bootstrap.collective
    attributes[config.membership_unit_association] = @second_unit
    config.membership_class.create!(**attributes)
  end

  def rp_session_for(headers)
    token_id = headers.fetch("X-TEST-SESSION-PUBLIC-ID")
    client_id = (@surface == :app) ? RpBaseAppSession::CLIENT_ID : RpBaseOrgSession::CLIENT_ID
    public_id = @base_browser_rp_session_public_ids.fetch([client_id, token_id])
    session_model.find_by!(public_id: public_id)
  end

  def session_model
    (@surface == :app) ? RpBaseAppSession : RpBaseOrgSession
  end

  def selection_model
    (@surface == :app) ? RpBaseAppSessionSelection : RpBaseOrgSessionSelection
  end

  def selector_url
    if @surface == :app
      base_app_selector_url(host: @host, ri: "jp")
    else
      base_org_selector_url(host: @host, ri: "jp")
    end
  end

  def ensure_token_references!(kind_class, status_class, binding_class, dbsc_status_class)
    kind_class.find_or_create_by!(id: kind_class::BROWSER_WEB)
    status_class.find_or_create_by!(id: status_class::ACTIVE)
    binding_class.find_or_create_by!(id: binding_class::LEGACY)
    dbsc_status_class.find_or_create_by!(id: dbsc_status_class::NOTHING)
  end

  def start_update(browser, candidate, headers, url, ready, release)
    Thread.new do
      rp_record_class.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
        ready << connection.select_value("SELECT pg_backend_pid()").to_i
        release.pop
        browser.patch(url, params: candidate.fetch(:public), headers:, as: :json)
        { candidate:,
          status: browser.response.status,
          body: browser.response.parsed_body,
          path_parameters: browser.request.path_parameters.slice(:controller, :action),
          request_id: browser.response.headers["X-Request-Id"],
          cache_control: browser.response.headers["Cache-Control"], }
      end
    rescue StandardError => e
      e
    end
  end

  def rp_record_class
    (@surface == :app) ? RpBaseAppRecord : RpBaseOrgRecord
  end

  def expected_selection(candidate)
    candidate.fetch(:public).slice(
      :account_public_id, :organization_public_id, :organization_unit_public_id, :avatar_public_id,
    ).compact.transform_keys(&:to_s)
  end

  def persisted_selection
    selection_model.find_by!(rp_session_id: @rp_session.id).attributes.slice(
      "account_public_id", "organization_public_id", "organization_unit_public_id", "avatar_public_id",
    ).compact
  end

  def response_summary(result)
    body = result.fetch(:body)
    details = body.is_a?(Hash) ? body.slice("status", "error") : body.to_s.lines.first.to_s.strip[0, 80]
    [result.fetch(:status), result.fetch(:path_parameters), result.fetch(:request_id),
     result.fetch(:cache_control), details,]
  end

  def cleanup_browser_session!
    return unless @rp_session

    rp_record_class.connected_to(role: :writing) do
      session = session_model.includes(op_session_binding: :identity_binding).find_by(id: @rp_session.id)
      next unless session

      binding = session.op_session_binding
      identity = binding.identity_binding
      principal_id = identity.principal_id
      selection_model.where(rp_session_id: session.id).delete_all
      event_receipt_model.where(op_session_binding_id: binding.id).delete_all
      session_model.where(id: session.id).delete_all
      op_session_binding_model.where(id: binding.id).delete_all
      identity_binding_model.where(id: identity.id).delete_all
      rp_principal_model.where(id: principal_id).delete_all
    end
  end

  def op_session_binding_model
    (@surface == :app) ? RpBaseAppOpSessionBinding : RpBaseOrgOpSessionBinding
  end

  def identity_binding_model
    (@surface == :app) ? RpBaseAppIdentityBinding : RpBaseOrgIdentityBinding
  end

  def rp_principal_model
    (@surface == :app) ? RpBaseAppPrincipal : RpBaseOrgPrincipal
  end

  def event_receipt_model
    (@surface == :app) ? RpBaseAppEventReceipt : RpBaseOrgEventReceipt
  end

  def cleanup_source_session!
    return unless @root_token

    token_model = (@surface == :app) ? ClientToken : OperatorToken
    grant_model = (@surface == :app) ? OpAppGrant : OpOrgGrant
    device_model = (@surface == :app) ? ClientDeviceSession : OperatorDeviceSession
    token_ids = token_model.where(id: @root_token.id).pluck(:id)
    grant_ids = grants_for_source_session(grant_model, token_ids)
    if @surface == :app
      OpAppGrantLogoutHint.where(grant_id: grant_ids).delete_all
      grant_model.where(id: grant_ids).delete_all
      ClientOidcAuthorizationTransaction.where.not(id: @transaction_ids_before).delete_all
    else
      OpOrgGrantLogoutHint.where(grant_id: grant_ids).delete_all
      grant_model.where(id: grant_ids).delete_all
      OperatorOidcAuthorizationTransaction.where.not(id: @transaction_ids_before).delete_all
    end
    device_ids = token_model.where(id: token_ids).where.not(device_session_id: nil).pluck(:device_session_id)
    token_model.where(id: token_ids).delete_all
    device_model.where(id: device_ids).delete_all
    @root_token = nil
  end

  def grants_for_source_session(grant_model, token_ids)
    owner_column = (@surface == :app) ? :client_token_id : :operator_token_id
    grant_model.where(owner_column => token_ids).pluck(:id)
  end

  def cleanup_actor_graph!
    return unless @principal

    (@surface == :app) ? cleanup_app_actor_graph! : cleanup_org_actor_graph!

    principal_model.where(id: @principal.id).delete_all
  end

  def principal_model
    (@surface == :app) ? Client : Operator
  end

  def cleanup_app_actor_graph!
    cleanup_app_avatar!
    cleanup_app_membership_and_units!
    cleanup_app_enterprise!
    cleanup_app_persona!
    ClientAccount.where(user_id: @principal.id).delete_all
    ClientIdentity.where(source_record_id: @principal.id).delete_all
    ClientAuthorityLock.where(client_id: @principal.id).delete_all
  end

  def cleanup_app_membership_and_units!
    persona_id = @bootstrap&.account&.id
    unit_ids = bootstrap_unit_ids
    PersonaMembership.where(persona_id:).delete_all if persona_id
    delete_unit_closures!(EnterpriseUnitClosure, unit_ids)
    EnterpriseUnit.where(id: unit_ids).delete_all if unit_ids.any?
  end

  def cleanup_app_enterprise!
    enterprise_ids = bootstrap_collective_ids
    EnterpriseOwnership.where(enterprise_id: enterprise_ids).delete_all if enterprise_ids.any?
    EnterpriseLifecycle.where(enterprise_id: enterprise_ids).delete_all if enterprise_ids.any?
    Enterprise.where(id: enterprise_ids).delete_all if enterprise_ids.any?
  end

  def cleanup_app_persona!
    persona_id = @bootstrap&.account&.id
    return unless persona_id

    ClientPersonaOwnership.where(client_persona_id: persona_id).delete_all
    ClientPersonaLifecycle.where(client_persona_id: persona_id).delete_all
    PersonaAssignment.where(persona_id:).delete_all
    ClientPersona.where(id: persona_id).delete_all
  end

  def cleanup_org_actor_graph!
    cleanup_org_membership_and_units!
    cleanup_org_bureau!
    cleanup_org_agent!
    OperatorAccount.where(staff_id: @principal.id).delete_all
    OperatorIdentity.where(source_record_id: @principal.id).delete_all
    OperatorAuthorityLock.where(operator_id: @principal.id).delete_all
    OperatorPasskey.where(staff_id: @principal.id).delete_all
  end

  def cleanup_org_membership_and_units!
    agent_id = @bootstrap&.account&.id
    unit_ids = bootstrap_unit_ids
    AgentMembership.where(agent_id:).delete_all if agent_id
    delete_unit_closures!(BureauUnitClosure, unit_ids)
    BureauUnit.where(id: unit_ids).delete_all if unit_ids.any?
  end

  def cleanup_org_bureau!
    bureau_ids = bootstrap_collective_ids
    BureauOwnership.where(bureau_id: bureau_ids).delete_all if bureau_ids.any?
    BureauLifecycle.where(bureau_id: bureau_ids).delete_all if bureau_ids.any?
    Bureau.where(id: bureau_ids).delete_all if bureau_ids.any?
  end

  def cleanup_org_agent!
    agent_id = @bootstrap&.account&.id
    return unless agent_id

    AgentOwnership.where(agent_id:).delete_all
    AgentLifecycle.where(agent_id:).delete_all
    AgentAssignment.where(agent_id:).delete_all
    Agent.where(id: agent_id).delete_all
  end

  def delete_unit_closures!(closure_class, unit_ids)
    return if unit_ids.empty?

    closure_class.where(ancestor_id: unit_ids).or(closure_class.where(descendant_id: unit_ids)).delete_all
  end

  def bootstrap_unit_ids
    return [] unless @bootstrap

    [@bootstrap.unit.id, @second_unit&.id].compact
  end

  def bootstrap_collective_ids
    @bootstrap ? [@bootstrap.collective.id] : []
  end

  def cleanup_app_avatar!
    avatar_id = @bootstrap&.avatar&.id
    return unless avatar_id

    AvatarRecord.connected_to(role: :writing) do
      connection = AvatarRecord.lease_connection
      connection.execute("SET session_replication_role = replica")
      binding_ids = AvatarPersonaBinding.where(persona_id: @bootstrap.account.id).pluck(:id)
      AvatarPersonaBinding.where(id: binding_ids).delete_all
      AvatarOwnershipPeriod.where(avatar_id: avatar_id).delete_all
      AvatarEnterpriseOwnershipPeriod.where(avatar_id: avatar_id).delete_all
      AvatarMoniker.where(avatar_id: avatar_id).delete_all
      handle_id = Avatar.find_by(id: avatar_id)&.active_handle_id
      Avatar.where(id: avatar_id).delete_all
      Handle.where(id: handle_id).delete_all if handle_id
    ensure
      connection&.execute("SET session_replication_role = origin")
    end
  end
end
