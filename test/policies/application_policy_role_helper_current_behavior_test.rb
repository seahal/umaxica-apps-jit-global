# typed: false
# frozen_string_literal: true

require "test_helper"

class ApplicationPolicyRoleHelperCurrentBehaviorTest < ActiveSupport::TestCase
  class RecordWithOrganization
    attr_reader :organization

    def initialize(organization)
      @organization = organization
    end
  end

  class RolelessActor
    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  test "role helpers currently delegate to user role methods and do not read JWT role claims" do
    Actor.reset
    Actor.authz = Actor::Authz.new(
      policy_user: nil, token_claims: { "scope" => "write:org", "roles" => ["operator"] },
      surface: "org",
    )
    policy = ApplicationPolicy.new(RecordWithOrganization.new(Object.new), user: RolelessActor.new(1))

    assert_raises(NoMethodError) { policy.send(:operator?) }
  ensure
    Actor.reset
  end
end
