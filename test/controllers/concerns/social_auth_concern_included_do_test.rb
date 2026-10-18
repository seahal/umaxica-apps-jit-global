# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SocialAuthConcernIncludedDoTest < ActiveSupport::TestCase
  test "VALID_INTENTS constant is defined" do
    assert_equal %w(login link step_up), SocialAuth::VALID_INTENTS
  end
end
