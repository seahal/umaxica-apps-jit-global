# frozen_string_literal: true

require "test_helper"

class RpWarpAppPrincipalTest < ActiveSupport::TestCase
  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::RpWarpAppPrincipal)
  end
end
