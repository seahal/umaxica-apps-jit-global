# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthorizationAuditIncludedDoTest < ActiveSupport::TestCase
  fixtures :visitors

  class Harness < ApplicationController
    include AuthorizationAudit
  end

  test "included do includes CommonRedirect module" do
    assert_includes Harness.included_modules, CommonRedirect,
                    "Harness should include CommonRedirect"
  end

  test "safe_redirect_back_or_to method available via included CommonRedirect" do
    harness = Harness.new

    assert_includes harness.private_methods, :safe_redirect_back_or_to,
                    "safe_redirect_back_or_to should be a private method"
  end
end
