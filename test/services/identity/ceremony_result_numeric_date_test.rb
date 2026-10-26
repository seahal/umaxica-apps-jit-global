# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityCeremonyResultNumericDateTest < ActiveSupport::TestCase
  RESULT_CLASSES = [
    IdentityEmailCeremonyResult,
    IdentityPasskeyCeremonyResult,
    IdentitySecretCredentialCeremonyResult,
    IdentityStepUpCeremonyResult,
    IdentityTelephoneCeremonyResult,
    IdentityTotpCeremonyResult,
  ].freeze

  setup do
    @now = Time.zone.parse("2026-06-18 01:08:54")
    @expires_at = @now + 10.minutes
  end

  test "result default claims normalize string-key expires_at to NumericDate seconds" do
    RESULT_CLASSES.each do |result_class|
      claims = result_class.default_claims({ "surface" => "app", "expires_at" => @expires_at }, now: @now)

      assert_instance_of Integer, claims["exp"], result_class.name
      assert_equal @expires_at.to_i, claims["exp"], result_class.name
    end
  end

  test "result default claims normalize symbol-key expires_at to NumericDate seconds" do
    RESULT_CLASSES.each do |result_class|
      claims = result_class.default_claims({ surface: "app", expires_at: @expires_at }, now: @now)

      assert_instance_of Integer, claims["exp"], result_class.name
      assert_equal @expires_at.to_i, claims["exp"], result_class.name
    end
  end

  test "result default claims reject invalid expires_at instead of coercing to zero" do
    RESULT_CLASSES.each do |result_class|
      assert_raises(ArgumentError, result_class.name) do
        result_class.default_claims({ surface: "app", expires_at: "not-a-timestamp" }, now: @now)
      end
    end
  end
end
