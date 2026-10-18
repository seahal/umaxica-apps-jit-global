# frozen_string_literal: true

require "test_helper"

class CoverbandProcessGateTest < ActiveSupport::TestCase
  test "measuring is off when COVERBAND_ENABLED is false" do
    env = { "COVERBAND_ENABLED" => "false" }

    assert_not CoverbandProcessGate.measuring?(argv: ["server"], program_name: "rails", environment: env)
    assert_not CoverbandProcessGate.enabled?(env)
  end

  test "measuring is on for rails server and puma when enabled" do
    env = { "COVERBAND_ENABLED" => "true" }

    assert CoverbandProcessGate.measuring?(argv: ["server"], program_name: "rails", environment: env)
    assert CoverbandProcessGate.measuring?(argv: ["s"], program_name: "rails", environment: env)
    assert CoverbandProcessGate.measuring?(argv: ["console"], program_name: "/usr/bin/puma", environment: env)
    assert_not CoverbandProcessGate.measuring?(argv: ["console"], program_name: "rails", environment: env)
  end
end
