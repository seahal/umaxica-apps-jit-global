# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AcmeSelectorTest < ActiveSupport::TestCase
  test "config_for returns config for app surface" do
    config = AcmeSelector.config_for(:app)

    assert_equal :app, config.surface
    assert_equal Client, config.principal_class
  end

  test "config_for returns config for org surface" do
    config = AcmeSelector.config_for(:org)

    assert_equal :org, config.surface
    assert_equal Operator, config.principal_class
  end

  test "config_for raises for unknown surface" do
    assert_raises(KeyError) do
      AcmeSelector.config_for(:unknown)
    end
  end
end
