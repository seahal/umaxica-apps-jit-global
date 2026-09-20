# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_registry"

# The registry refuses malformed configuration by naming what is wrong and where,
# because a JWT issuer that boots with a broken key is a signing outage the first
# request discovers. These pin the validation arms that answer with a
# ConfigurationError rather than letting the bad value through.
module Jit
  module Security
    module Jwt
      class RegistryValidationTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        test "auth keyring audiences are the union of the per-resource-type audiences" do
          audiences = JitSecurityJwtRegistry.issuer("auth").audiences

          assert_equal %w(umaxica-api-client umaxica-api-visitor umaxica-api-operator).sort, audiences.sort
        end
      end
    end
  end
end
