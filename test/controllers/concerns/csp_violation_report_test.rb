# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CspViolationReportTest < ActiveSupport::TestCase
  class Harness
    include CspViolationReport

    attr_reader :head_args

    def head(*args)
      @head_args = args
    end
  end

  class RateLimitedHarness < ApplicationController
    include CspViolationReport

    def self.rate_limit(**)
    end
  end

  test "protect_csp_violation_report_intake registers rescue and rate limit when available" do
    assert_nothing_raised do
      RateLimitedHarness.protect_csp_violation_report_intake
    end
  end
end
