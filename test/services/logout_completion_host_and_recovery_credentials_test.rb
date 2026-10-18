# typed: false
# frozen_string_literal: true

require "test_helper"

# Both of these map an actor or an origin onto surface-specific configuration.
# The mapping has to be exhaustive: an origin that resolves to the wrong host
# sends a logout completion to another surface, and a credential class that
# resolves to the wrong relation counts, or issues, another surface's passcodes.
class LogoutCompletionHostAndRecoveryCredentialsTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses

  def hosts = Rails.configuration.x.boot_config.fetch(:hosts)

  test "each origin surface resolves the completion host of its own realm" do
    {
      ["base", "app"] => hosts.base_service.host,
      ["base", "com"] => hosts.base_corporate.host,
      ["base", "org"] => hosts.base_staff.host,
      ["acme", "org"] => hosts.base_staff.host,
      ["core", "app"] => hosts.core_service.host,
      ["core", "com"] => hosts.core_corporate.host,
      ["core", "org"] => hosts.core_staff.host,
      ["warp", "app"] => hosts.warp_service.host,
      ["warp", "com"] => hosts.warp_corporate.host,
      ["warp", "org"] => hosts.warp_staff.host,
      ["palm", "app"] => hosts.palm_service.host,
    }.each do |(origin, surface), expected|
      assert_equal expected,
                   AcmeLogoutTransactionCoordinator.completion_host_for(origin_surface: origin, surface: surface),
                   "#{origin}/#{surface}"
    end
  end

  test "an origin surface with no realm is named in the error rather than defaulted" do
    error =
      assert_raises(ArgumentError) do
        AcmeLogoutTransactionCoordinator.completion_host_for(origin_surface: "martian", surface: "app")
      end

    assert_match(/unsupported logout origin surface/, error.message)
  end

  test "a logout challenge that names no transaction is reported as missing rather than raising" do
    result = AcmeLogoutTransactionCoordinator.finalize!(logout_challenge: "no-such-challenge")

    assert_equal :missing, result.status
    assert_equal "not_found", result.error
    assert_nil result.transaction
  end
end
