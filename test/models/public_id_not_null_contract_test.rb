# frozen_string_literal: true

require "test_helper"

class PublicIdNotNullContractTest < ActiveSupport::TestCase
  [
    ClientPreference,
    VisitorPreference,
    OperatorPreference,
    ClientPasskey,
  ].each do |model|
    test "#{model.name} requires a persisted public identity" do
      assert_not model.columns_hash.fetch("public_id").null
    end
  end
end
