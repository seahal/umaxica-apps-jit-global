# typed: false
# frozen_string_literal: true

require "test_helper"

# Defaults and delegations that only run when a surface supplies nothing of its
# own: the visitor surface defers its session cap for every other principal
# kind, the RP identity state falls back to the active id when no state
# association is declared, and the DBSC endpoint resolves no resource at all
# when the request carries no access cookie.
class SurfaceSeamDefaultsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "the preference verification key is resolved for the active key id" do
    assert_equal PreferenceJwtConfiguration.public_key_for(PreferenceJwtConfiguration.active_kid),
                 PreferenceJwtConfiguration.public_key
  end
end
