# typed: false
# frozen_string_literal: true

require "test_helper"

# Bulk rotation counts what it could not rewrite as well as what it could, so an
# operator running an emergency rotation sees the residue rather than a clean
# report. The token and cycle lookups alongside it answer nothing rather than
# raising when the thing they were asked about does not resolve.
class RotationCountingAndTokenActorTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities, :client_token_kinds, :client_token_statuses

  # A stored locator whose payload is missing a key it needs is treated as no
  # cycle at all, rather than raising out of a before_action.
  test "a locator payload missing a key resolves to no cycle rather than raising" do
    locator = SignInCycleLocator.new({ app_sign_in_flow_locator: { "public_id" => "x" } }, surface: :app)

    assert_nil locator.current

    empty = SignInCycleLocator.new({}, surface: :app)

    assert_nil empty.current
  end
end
