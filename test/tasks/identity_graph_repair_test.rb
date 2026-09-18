# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "rake"

# Load only the task under test rather than every file under lib/tasks/; a full
# `load_tasks` also re-evaluates unrelated rake files and warns about their
# constants being reinitialized. The Rails environment is already booted here,
# so the task's `:environment` prerequisite only needs to exist.
Rake::Task.define_task(:environment) unless Rake::Task.task_defined?("environment")
load Rails.root.join("lib/tasks/identity_graph_repair.rake")

class IdentityGraphRepairTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ensure_reference_rows!
  end

  test "repairs missing app graphs" do
    user = create_client!

    with_identity_graph_repair_env(surface: "app", dry_run: "false") do
      assert_output(/identity_graph_repair surface=app dry_run=false .*failed=0/) do
        invoke_repair_task
      end
    end

    assert_equal 1, ClientIdentity.where(source_record_id: user.id).count
    assert_equal 1, ClientAccount.where(user_id: user.id).count
    assert_equal 1, ClientPersona.where(client_identity_id: ClientIdentity.find_by!(source_record_id: user.id).id).count
  end

  test "does not duplicate an already provisioned graph" do
    user = create_client!
    IdentityGraphProvisioner.call!(surface: :app, principal: user)

    with_identity_graph_repair_env(surface: "app", dry_run: "false") do
      assert_output(/identity_graph_repair surface=app dry_run=false/) do
        invoke_repair_task
      end
    end

    assert_equal 1, ClientIdentity.where(source_record_id: user.id).count
    assert_equal 1, ClientAccount.where(user_id: user.id).count
  end

  test "dry run reports missing graphs without changing records" do
    user = create_client!

    with_identity_graph_repair_env(surface: "app", dry_run: "true") do
      assert_output(/identity_graph_repair surface=app dry_run=true .*repaired=0/) do
        invoke_repair_task
      end
    end

    assert_nil ClientIdentity.find_by(source_record_id: user.id)
    assert_nil ClientAccount.find_by(user_id: user.id)
  end

  test "continues after a failure and repairs later principals" do
    first = create_client!
    second = create_client!

    with_identity_graph_repair_env(surface: "app", dry_run: "false") do
      IdentityGraphProvisioner.stub(
        :call!,
        lambda do |surface:, principal:|
          raise RuntimeError, "boom" if principal.id == first.id

          BaseSelectorBootstrapAuthority.call(surface: surface, principal: principal)
        end,
      ) do
        assert_output(/identity_graph_repair surface=app dry_run=false .*failed=1/) do
          invoke_repair_task
        end
      end
    end

    assert_nil ClientIdentity.find_by(source_record_id: first.id)
    assert_equal 1, ClientIdentity.where(source_record_id: second.id).count
  end

  private

  def ensure_reference_rows!
    [
      ClientStatus, ClientVisibility, ClientMfaLevel, ClientMfaStatus,
      ClientIdentityState, PersonaMembershipKind, PersonaMembershipState,
      HandleStatus, AvatarCapability,
    ].each { |klass| klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!) }
  end

  def create_client!
    Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
  end

  def invoke_repair_task
    Rake::Task["identity_graph:repair"].reenable
    Rake::Task["identity_graph:repair"].invoke
  end

  def with_identity_graph_repair_env(surface:, dry_run:)
    previous_surface = ENV["SURFACE"]
    previous_dry_run = ENV["DRY_RUN"]
    ENV["SURFACE"] = surface
    ENV["DRY_RUN"] = dry_run
    yield
  ensure
    ENV["SURFACE"] = previous_surface
    ENV["DRY_RUN"] = previous_dry_run
  end
end
