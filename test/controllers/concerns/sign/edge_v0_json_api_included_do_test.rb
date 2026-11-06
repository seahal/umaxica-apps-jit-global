# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignEdgeV0JsonApiIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include SignEdgeV0JsonApi
  end

  test "including edge json api does not register callbacks implicitly" do
    filters = Harness._process_action_callbacks.map(&:filter)

    assert_not_includes filters, :ensure_json_request
    assert_empty Harness._process_action_callbacks.select { |callback| callback.filter == :set_region }
  end

  test "edge token controllers own json callback explicitly" do
    filters = Visa::App::Edge::V0::Token::ChecksController._process_action_callbacks.map(&:filter)

    assert_includes filters, :ensure_json_request
  end
end
