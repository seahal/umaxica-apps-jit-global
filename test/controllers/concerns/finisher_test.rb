# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class FinisherTest < ActiveSupport::TestCase
  class DummyController < ApplicationController
    include ::Finisher
  end

  test "dummy controller includes finisher" do
    assert_includes DummyController.ancestors, ::Finisher
  end
end
