# typed: false
# frozen_string_literal: true

require "test_helper"
require "rake"

Rake::Task.define_task(:environment) unless Rake::Task.task_defined?("environment")
load Rails.root.join("lib/tasks/identity_graph_repair.rake")

class IdentityGraphRepairTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @previous_surface = ENV["SURFACE"]
    @previous_dry_run = ENV["DRY_RUN"]
    [
      ClientStatus, ClientVisibility, ClientMfaLevel, ClientMfaStatus,
      VisitorStatus, VisitorVisibility, VisitorMfaLevel, VisitorMfaStatus,
      OperatorStatus, OperatorVisibility, OperatorMfaLevel, OperatorMfaStatus,
      ClientIdentityState, VisitorIdentityState, OperatorIdentityState,
      PersonaMembershipKind, PersonaMembershipState,
      IndividualMembershipKind, IndividualMembershipState,
      AgentMembershipKind, AgentMembershipState, HandleStatus,
    ].each { |klass| klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!) }
    AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
  end

  teardown do
    @previous_surface.nil? ? ENV.delete("SURFACE") : ENV["SURFACE"] = @previous_surface
    @previous_dry_run.nil? ? ENV.delete("DRY_RUN") : ENV["DRY_RUN"] = @previous_dry_run
  end

  test "repairs missing app graphs" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    ENV["SURFACE"] = "app"
    ENV["DRY_RUN"] = "false"

    assert_output(/identity_graph_repair surface=app dry_run=false .*failed=0/) do
      Rake::Task["identity_graph:repair"].reenable
      Rake::Task["identity_graph:repair"].invoke
    end

    identity = ClientIdentity.find_by!(source_record_id: user.id)

    assert_equal 1, ClientAccount.where(user_id: user.id).count
    assert_equal 1, ClientPersona.where(client_identity_id: identity.id).count
  end

  test "does not duplicate an already provisioned app graph" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    IdentityGraphProvisioner.call!(surface: :app, principal: user)
    ENV["SURFACE"] = "app"
    ENV["DRY_RUN"] = "false"

    assert_output(/identity_graph_repair surface=app dry_run=false/) do
      Rake::Task["identity_graph:repair"].reenable
      Rake::Task["identity_graph:repair"].invoke
    end

    assert_equal 1, ClientIdentity.where(source_record_id: user.id).count
    assert_equal 1, ClientAccount.where(user_id: user.id).count
  end

  test "dry run reports a missing app graph without changing records" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    ENV["SURFACE"] = "app"
    ENV["DRY_RUN"] = "true"

    assert_output(/identity_graph_repair surface=app dry_run=true .*repaired=0/) do
      Rake::Task["identity_graph:repair"].reenable
      Rake::Task["identity_graph:repair"].invoke
    end

    assert_nil ClientIdentity.find_by(source_record_id: user.id)
    assert_nil ClientAccount.find_by(user_id: user.id)
  end

  test "continues after an app graph failure and repairs later principals" do
    first = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    second = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    ENV["SURFACE"] = "app"
    ENV["DRY_RUN"] = "false"

    IdentityGraphProvisioner.stub(
      :call!,
      lambda do |surface:, principal:|
        raise RuntimeError, "boom" if principal.id == first.id

        BaseSelectorBootstrapAuthority.call(surface: surface, principal: principal)
      end,
    ) do
      assert_output(/identity_graph_repair surface=app dry_run=false .*failed=1/) do
        Rake::Task["identity_graph:repair"].reenable
        Rake::Task["identity_graph:repair"].invoke
      end
    end

    assert_nil ClientIdentity.find_by(source_record_id: first.id)
    assert_equal 1, ClientIdentity.where(source_record_id: second.id).count
  end

  test "skips login-blocked and admin-locked app principals as ineligible without provisioning them" do
    reserved = Client.create!(status_id: ClientStatus::RESERVED, visibility_id: ClientVisibility::USER)
    locked = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    locked.update_columns(access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED)
    eligible = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER)
    ENV["SURFACE"] = "app"
    ENV["DRY_RUN"] = "false"

    assert_output(/identity_graph_repair surface=app dry_run=false .*failed=0 ineligible=[2-9]/) do
      Rake::Task["identity_graph:repair"].reenable
      Rake::Task["identity_graph:repair"].invoke
    end

    assert_nil ClientIdentity.find_by(source_record_id: reserved.id)
    assert_nil ClientIdentity.find_by(source_record_id: locked.id)
    assert_equal 1, ClientIdentity.where(source_record_id: eligible.id).count
  end

  test "org selector-ready graph does not require an Avatar" do
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    bootstrap = IdentityGraphProvisioner.call!(surface: :org, principal: operator)

    assert IdentityGraphRepair.selector_ready_graph?(AcmeSelector.config_for(:org), operator)

    bureau = bootstrap.collective

    assert_not Avatar
      .joins(:current_ownership_period)
      .exists?(avatar_ownership_periods: {
        owner_surface: "org",
        owner_collective_public_id: bureau.public_id,
      })
  end
end
