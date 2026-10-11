# frozen_string_literal: true

require "test_helper"

class ActionMailerLoggingPolicyTest < ActiveSupport::TestCase
  test "disables the shared ActionMailer logger without replacing delivery" do
    assert_nil ActionMailer::Base.logger
    assert_equal :test, ActionMailer::Base.delivery_method
  end
end
