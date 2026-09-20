# typed: false
# frozen_string_literal: true

require "test_helper"

# The staff sign-in preflight is a diagnostic: it reports which parts of the
# Entra configuration are usable. Every check has to answer rather than raise,
# because a preflight that itself falls over tells an operator nothing about the
# thing they came to check.
class OrgEntraPreflightDiscoveryTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses

  def check(result, name)
    result.checks.find { |candidate| candidate.name == name }
  end

  # An unreachable tenant is a failed check with the reason, not a failed
  # preflight: the operator still needs to see the other checks.
  test "an unreachable tenant fails only the issuer check and the rest still report" do
    unreachable = ->(_tenant_id) { raise Faraday::ConnectionFailed, "tenant unreachable" }
    result = OrgEntraSignInPreflight.new(metadata_fetcher: unreachable).call

    issuer = check(result, "issuer")

    assert_not issuer.ok
    assert_match(/could not reach the tenant/, issuer.detail)
    assert_equal 5, result.checks.size
    assert check(result, "provisioning"), "the remaining checks still have to report"
  end

  test "provisioning reports how many identities are active rather than only whether any are" do
    result = OrgEntraSignInPreflight.new(metadata_fetcher: ->(_tenant_id) { {} }).call
    provisioning = check(result, "provisioning")

    assert_equal OperatorEntraIdentity.where(status_id: OperatorEntraIdentityState::ACTIVE).count.positive?,
                 provisioning.ok
    assert_predicate provisioning.detail, :present?
  end
end
