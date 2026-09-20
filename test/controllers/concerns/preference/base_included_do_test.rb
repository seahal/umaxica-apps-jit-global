# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceBaseIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include PreferenceBase
  end

  test "ACCESS_TOKEN_TTL constant is defined" do
    assert_kind_of ActiveSupport::Duration, PreferenceBase::ACCESS_TOKEN_TTL
  end

  test "REFRESH_TOKEN_TTL constant is defined" do
    assert_kind_of ActiveSupport::Duration, PreferenceBase::REFRESH_TOKEN_TTL
  end

  test "including base does not register preference callbacks implicitly" do
    callbacks = Harness._process_action_callbacks.map(&:filter)

    assert_not_includes callbacks, :set_preferences_cookie
  end
end
