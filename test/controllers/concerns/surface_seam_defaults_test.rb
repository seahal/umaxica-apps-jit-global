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

  test "each preference verification key is resolved from its realm issuer" do
    %w(preference_app preference_com preference_org).each do |issuer_id|
      issuer = JitSecurityJwtRegistry.issuer(issuer_id)
      key = PreferenceJwtConfiguration.public_key_for(issuer.current_kid, issuer_id: issuer_id)

      assert_equal issuer.public_key_for(issuer.current_kid), key
    end
  end
end
