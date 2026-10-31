# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class DpopProofStateStoreTest < ActiveSupport::TestCase
  test "for resolves operator and default client" do
    assert_equal OperatorDpopProofState, DpopProofStateStore.for("operator")
    assert_equal ClientDpopProofState, DpopProofStateStore.for("unknown")
    assert_equal ClientDpopProofState, DpopProofStateStore.for(nil)
  end
end
