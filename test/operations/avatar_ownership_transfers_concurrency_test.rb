# frozen_string_literal: true

require "test_helper"
require "timeout"
require_relative "../support/avatar_test_factory"

# Independent PostgreSQL connections are required to exercise the persistent ownership lock.
# rubocop:disable ThreadSafety/NewThread
class AvatarOwnershipTransfersConcurrencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  setup do
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientIdentityState.ensure_defaults!
    PersonaMembershipKind.ensure_defaults!
    PersonaMembershipState.ensure_defaults!
    AvatarOwnershipStatus.ensure_defaults!
    AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    HandleStatus.ensure_defaults!

    @client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @client_identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-transfer-race-#{SecureRandom.hex(8)}",
      audience: "acme_app",
      source_record_id: @client.id,
      status_id: ClientIdentityState::ACTIVE,
    )
    @persona = ClientPersona.create!(client_identity: @client_identity, title: "Race")
    @enterprise =
      I18n.with_locale(:en) do
        Enterprise.create!(name: "Race owner", title: "RaceOwner")
      end
    @unit = EnterpriseUnit.create!(enterprise: @enterprise, name: "Race owner root")
    @membership = PersonaMembership.create!(
      persona: @persona,
      enterprise: @enterprise,
      enterprise_unit: @unit,
      membership_kind_id: PersonaMembershipKind::OWNER,
      membership_state_id: PersonaMembershipState::ACTIVE,
      primary: true,
    )
    @bureau =
      I18n.with_locale(:en) do
        Bureau.create!(name: "Race target", title: "RaceTarget")
      end
    handle = Handle.create!(
      handle: "avatar-transfer-race-#{SecureRandom.hex(5)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    @avatar = AvatarTestFactory.create!(
      moniker: "Transfer race",
      capability_id: AvatarCapability::NORMAL,
      active_handle: handle,
    )
    @handle = handle
    AvatarOwnershipPeriod.create!(
      avatar: @avatar,
      owner_organization_id: @enterprise.public_id,
      owner_surface: "app",
      owner_collective_public_id: @enterprise.public_id,
      avatar_ownership_status_id: AvatarOwnershipStatus::ACTIVE,
      valid_from: Time.current,
    )
  end

  teardown do
    if @avatar
      AvatarOwnershipTransfer.where(avatar_id: @avatar.id).delete_all
      GroupAvatarMembership.where(avatar_id: @avatar.id).delete_all
      AvatarOwnershipPeriod.where(avatar_id: @avatar.id).delete_all
      AvatarMoniker.where(avatar_id: @avatar.id).delete_all
      Avatar.where(id: @avatar.id).delete_all
    end
    Handle.where(id: @handle.id).delete_all if @handle

    if @bureau
      BureauOwnership.where(bureau_id: @bureau.id).delete_all
      BureauLifecycle.where(bureau_id: @bureau.id).delete_all
      Bureau.where(id: @bureau.id).delete_all
    end
    if @unit
      EnterpriseUnitClosure.where(ancestor_id: @unit.id).or(
        EnterpriseUnitClosure.where(descendant_id: @unit.id),
      ).delete_all
      PersonaMembership.where(id: @membership.id).delete_all if @membership
      EnterpriseUnit.where(id: @unit.id).delete_all
    end
    if @enterprise
      EnterpriseOwnership.where(enterprise_id: @enterprise.id).delete_all
      EnterpriseLifecycle.where(enterprise_id: @enterprise.id).delete_all
      Enterprise.where(id: @enterprise.id).delete_all
    end
    ClientPersonaOwnership.where(client_persona_id: @persona.id).delete_all if @persona
    ClientPersonaLifecycle.where(client_persona_id: @persona.id).delete_all if @persona
    PersonaAssignment.where(persona_id: @persona.id).delete_all if @persona
    ClientPersona.where(id: @persona.id).delete_all if @persona
    ClientIdentity.where(id: @client_identity.id).delete_all if @client_identity
    ClientAuthorityLock.where(client_id: @client.id).delete_all if @client
    Client.where(id: @client.id).delete_all if @client
  end

  test "two independent requests cannot create multiple pending transfers for one Avatar" do
    avatar_public_id = @avatar.public_id
    client_id = @client.id
    persona_public_id = @persona.public_id
    target_public_id = @bureau.public_id
    ready = Queue.new
    start = Queue.new

    ActiveRecord::Base.connection_handler.clear_active_connections!
    threads =
      2.times.map do
        Thread.new do
          AppRpRecord.connection_pool.with_connection do |connection|
            backend_pid = connection.select_value("SELECT pg_backend_pid()")
            ready << backend_pid
            start.pop
            AvatarOwnershipTransfers::RequestOperation.call(
              actor: Client.find(client_id),
              surface: "app",
              subject_public_id: persona_public_id,
              avatar_public_id: avatar_public_id,
              target_surface: "org",
              target_collective_public_id: target_public_id,
            )
            [backend_pid, :created]
          rescue AvatarOwnershipTransfers::InvalidTransfer
            [backend_pid, :rejected]
          rescue ActiveRecord::RecordNotUnique
            [backend_pid, :unique_index_rejected]
          end
        end
      end

    begin
      pids = Timeout.timeout(5) { 2.times.map { ready.pop } }
      2.times { start << true }
      results = Timeout.timeout(15) { threads.map(&:value) }
    ensure
      threads.each do |thread|
        thread.kill if thread.alive?
        thread.join
      end
    end

    states = results.map(&:last)

    assert_equal 2, pids.uniq.length
    assert_equal 1, states.count(:created)
    assert_equal 1, states.count { |state| %i(rejected unique_index_rejected).include?(state) }
    assert_equal 1, AvatarOwnershipTransfer.pending.where(avatar_id: @avatar.id).count
  end

  test "group creation waits for a concurrent owner-membership revocation" do
    assert_group_creation_waits_for_membership_downgrade(
      account_surface: "app",
      connection_owner: AppRpRecord,
      membership_class: PersonaMembership,
      membership: @membership,
      member_kind_id: PersonaMembershipKind::MEMBER,
      actor: @client,
      subject_public_id: @persona.public_id,
      owner_collective_public_id: @enterprise.public_id,
    )
  end

  test "group creation waits for a concurrent org owner-membership revocation" do
    OperatorStatus.ensure_defaults!
    OperatorVisibility.ensure_defaults!
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    membership = bootstrap.account.agent_memberships.find_by!(bureau: bootstrap.collective)

    assert_group_creation_waits_for_membership_downgrade(
      account_surface: "org",
      connection_owner: OrgRpRecord,
      membership_class: AgentMembership,
      membership: membership,
      member_kind_id: AgentMembershipKind::MEMBER,
      actor: operator,
      subject_public_id: bootstrap.account.public_id,
      owner_collective_public_id: bootstrap.collective.public_id,
    )
  ensure
    delete_org_bootstrap_data!(operator, bootstrap) if operator && bootstrap
  end

  test "group creation waits for a concurrent app principal deactivation" do
    assert_group_creation_waits_for_principal_deactivation(
      account_surface: "app",
      connection_owner: AppZenithRecord,
      actor: @client,
      deactivated_status_id: ClientStatus::RESERVED,
      subject_public_id: @persona.public_id,
      owner_collective_public_id: @enterprise.public_id,
    )
  end

  test "group creation waits for a concurrent org principal deactivation" do
    OperatorStatus.ensure_defaults!
    OperatorVisibility.ensure_defaults!
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)

    assert_group_creation_waits_for_principal_deactivation(
      account_surface: "org",
      connection_owner: OrgZenithRecord,
      actor: operator,
      deactivated_status_id: OperatorStatus::RESERVED,
      subject_public_id: bootstrap.account.public_id,
      owner_collective_public_id: bootstrap.collective.public_id,
    )
  ensure
    delete_org_bootstrap_data!(operator, bootstrap) if operator && bootstrap
  end

  private

  def assert_group_creation_waits_for_membership_downgrade(account_surface:, connection_owner:,
                                                           membership_class:, membership:,
                                                           member_kind_id:, actor:, subject_public_id:,
                                                           owner_collective_public_id:)
    group_name = "#{account_surface} revocation race #{SecureRandom.hex(6)}"
    operation_thread = nil
    operation_started = Queue.new

    with_downgraded_membership(connection_owner, membership_class, membership, member_kind_id) do
      operation_thread = start_group_creation_thread(
        connection_owner: connection_owner,
        operation_started: operation_started,
        account_surface: account_surface,
        subject_public_id: subject_public_id,
        owner_collective_public_id: owner_collective_public_id,
        actor: actor,
        group_name: group_name,
      )
      backend_pid = Timeout.timeout(5) { operation_started.pop }

      assert_database_row_lock_wait(
        connection_owner: connection_owner,
        lock_table_name: membership_class.table_name,
        lock_description: "group creation owner-membership authorization",
        backend_pid: backend_pid,
        operation_thread: operation_thread,
      )
    end

    assert_equal [:denied, "avatar.group.manage permission required"], operation_thread.value
    assert_not AvatarGroup.exists?(account_surface:, account_public_id: subject_public_id, name: group_name)
  ensure
    operation_thread&.join(5)
    operation_thread&.kill if operation_thread&.alive?
    operation_thread&.join
    delete_group(account_surface:, account_public_id: subject_public_id, name: group_name)
  end

  def assert_group_creation_waits_for_principal_deactivation(account_surface:, connection_owner:, actor:,
                                                             deactivated_status_id:, subject_public_id:,
                                                             owner_collective_public_id:)
    group_name = "#{account_surface} principal deactivation race #{SecureRandom.hex(6)}"
    operation_thread = nil
    operation_started = Queue.new

    with_deactivated_principal(connection_owner, actor, deactivated_status_id) do
      operation_thread = start_group_creation_thread(
        connection_owner: connection_owner,
        operation_started: operation_started,
        account_surface: account_surface,
        subject_public_id: subject_public_id,
        owner_collective_public_id: owner_collective_public_id,
        actor: actor,
        group_name: group_name,
      )
      backend_pid = Timeout.timeout(5) { operation_started.pop }

      assert_database_row_lock_wait(
        connection_owner: connection_owner,
        lock_table_name: actor.class.table_name,
        lock_description: "group creation principal authorization",
        backend_pid: backend_pid,
        operation_thread: operation_thread,
      )
    end

    assert_equal [:denied, "Avatar owner actor must be active"], operation_thread.value
    assert_not AvatarGroup.exists?(account_surface:, account_public_id: subject_public_id, name: group_name)
  ensure
    operation_thread&.join(5)
    operation_thread&.kill if operation_thread&.alive?
    operation_thread&.join
    delete_group(account_surface:, account_public_id: subject_public_id, name: group_name)
  end

  def with_downgraded_membership(connection_owner, membership_class, membership, member_kind_id)
    connection_owner.connected_to(role: :writing) do
      connection_owner.transaction do
        membership_class.lock.find(membership.id).update!(membership_kind_id: member_kind_id)
        yield
      end
    end
  end

  def with_deactivated_principal(connection_owner, actor, status_id)
    connection_owner.connected_to(role: :writing) do
      connection_owner.transaction do
        actor.class.lock.find(actor.id).update!(status_id: status_id)
        yield
      end
    end
  end

  def start_group_creation_thread(connection_owner:, operation_started:, account_surface:,
                                  subject_public_id:, owner_collective_public_id:, actor:, group_name:)
    Thread.new do
      connection_owner.connection_pool.with_connection do |connection|
        backend_pid = Integer(connection.select_value("SELECT pg_backend_pid()"))
        operation_started << backend_pid
        begin
          group = GroupManagement::Create.call(
            account_surface: account_surface,
            account_public_id: subject_public_id,
            owner_surface: account_surface,
            owner_collective_public_id: owner_collective_public_id,
            actor: actor.class.find(actor.id),
            subject_public_id: subject_public_id,
            name: group_name,
          )
          [:created, group.id]
        rescue GroupManagement::Create::AuthorizationDenied => e
          [:denied, e.message]
        end
      end
    end
  end

  def assert_database_row_lock_wait(connection_owner:, lock_table_name:, lock_description:,
                                    backend_pid:, operation_thread:)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    waiting_for_lock = false

    loop do
      activity = connection_owner.connection.select_one(
        "SELECT wait_event_type, query FROM pg_stat_activity WHERE pid = #{backend_pid}",
      )
      waiting_for_lock = activity && activity.fetch("wait_event_type") == "Lock" &&
        activity.fetch("query").match?(/FROM "#{lock_table_name}".*FOR UPDATE/im)
      break if waiting_for_lock || !operation_thread.alive?
      raise Timeout::Error, "#{lock_description} did not reach its row lock" if
        Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end

    assert waiting_for_lock,
           "#{lock_description} must lock #{lock_table_name} before writing Avatar data"
  end

  def delete_group(account_surface:, account_public_id:, name:)
    group = AvatarGroup.find_by(account_surface:, account_public_id:, name:)
    return unless group

    GroupAvatarMembership.where(avatar_group_id: group.id).delete_all
    AvatarGroupOwnershipPeriod.where(avatar_group_id: group.id).delete_all
    group.delete
  end

  def delete_org_bootstrap_data!(operator, bootstrap)
    OrgRpRecord.connected_to(role: :writing) do
      OrgRpRecord.transaction do
        delete_agent_bootstrap_data!(bootstrap.account)
        OperatorIdentity.where(id: bootstrap.account.operator_identity_id).delete_all
        OperatorAuthorityLock.where(operator_id: operator.id).delete_all
        delete_bureau_bootstrap_data!(bootstrap.collective)
      end
    end
    Operator.where(id: operator.id).delete_all
  end

  def delete_agent_bootstrap_data!(agent)
    AgentMembership.where(agent_id: agent.id).delete_all
    AgentAssignment.where(agent_id: agent.id).delete_all
    AgentOwnership.where(agent_id: agent.id).delete_all
    AgentLifecycle.where(agent_id: agent.id).delete_all
    Agent.where(id: agent.id).delete_all
  end

  def delete_bureau_bootstrap_data!(bureau)
    BureauOwnership.where(bureau_id: bureau.id).delete_all
    BureauLifecycle.where(bureau_id: bureau.id).delete_all
    unit_ids = BureauUnit.where(bureau_id: bureau.id).pluck(:id)
    BureauUnitClosure.where(ancestor_id: unit_ids).or(
      BureauUnitClosure.where(descendant_id: unit_ids),
    ).delete_all
    BureauUnit.where(id: unit_ids).delete_all
    Bureau.where(id: bureau.id).delete_all
  end
end
# rubocop:enable ThreadSafety/NewThread
