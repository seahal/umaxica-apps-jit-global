# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityGraphProvisionerTest < ActiveSupport::TestCase
  setup do
    ensure_reference_rows!
  end

  test "delegates to selector bootstrap authority" do
    user = create_client!

    BaseSelectorBootstrapAuthority.stub(:call, :provisioned) do
      assert_equal :provisioned, IdentityGraphProvisioner.call!(surface: :app, principal: user)
    end
  end

  test "logs and re-raises bootstrap failures" do
    user = create_client!
    error = RuntimeError.new("bootstrap boom")
    logged = nil

    BaseSelectorBootstrapAuthority.stub(:call, ->(*) { raise error }) do
      Rails.logger.stub(:error, ->(message) { logged = message }) do
        raised =
          assert_raises(RuntimeError) do
            IdentityGraphProvisioner.call!(surface: :app, principal: user)
          end

        assert_same error, raised
      end
    end

    assert_includes logged, "identity.graph_provisioning.failed"
    assert_includes logged, "bootstrap boom"
    assert_includes logged, "Client"
  end

  test "is idempotent for an already provisioned principal" do
    user = create_client!

    assert_difference -> { ClientAccount.count }, 1 do
      IdentityGraphProvisioner.call!(surface: :app, principal: user)
    end

    assert_no_difference -> {
      ClientAccount.count + ClientIdentity.count + ClientPersona.count + Enterprise.count + Avatar.count
    } do
      IdentityGraphProvisioner.call!(surface: :app, principal: user)
    end
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
end
