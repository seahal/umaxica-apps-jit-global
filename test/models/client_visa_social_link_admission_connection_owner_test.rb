# frozen_string_literal: true

require "test_helper"

class ClientVisaSocialLinkAdmissionConnectionOwnerTest < ActiveSupport::TestCase
  test "social-link admission persistence stays in the OP APP database" do
    assert_equal OpBaseAppRecord, ClientVisaSocialLinkAdmission.connection_owner
  end
end
