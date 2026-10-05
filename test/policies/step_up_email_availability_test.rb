# frozen_string_literal: true

require "test_helper"

class StepUpEmailAvailabilityTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  fixtures :client_statuses, :client_visibilities, :client_mfa_levels, :client_mfa_statuses
  fixtures :visitor_statuses, :visitor_visibilities, :visitor_mfa_levels, :visitor_mfa_statuses

  [-1, 0, 1].each do |offset|
    test "APP Email OTP lockout availability at deadline offset #{offset} microseconds preserves configured state" do
      now = Time.zone.at(Time.current.to_i)
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      actor.client_emails.create!(
        address: "availability@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
        step_up_otp_failures: 5, step_up_otp_locked_until: now + Rational(offset, 1_000_000),
      )
      result = nil
      Client.stub(:database_now, now) do
        result = StepUpMethodsResolver.call(actor: actor, ticket: nil, supported_methods: [:email_otp])
      end

      assert_equal [:email_otp], result.configured
      assert_equal((offset.positive? ? [] : [:email_otp]), result.available)
      assert_not StepUpBootstrapEligibilityQuery.call(actor: actor)
    end

    test "COM Email OTP lockout availability at deadline offset #{offset} microseconds preserves configured state" do
      now = Time.zone.at(Time.current.to_i)
      actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
      actor.visitor_emails.create!(
        address: "availability@example.com", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        step_up_otp_failures: 5, step_up_otp_locked_until: now + Rational(offset, 1_000_000),
      )
      result = nil
      Visitor.stub(:database_now, now) do
        result = StepUpMethodsResolver.call(actor: actor, ticket: nil, supported_methods: [:email_otp])
      end

      assert_equal [:email_otp], result.configured
      assert_equal((offset.positive? ? [] : [:email_otp]), result.available)
      assert_not StepUpBootstrapEligibilityQuery.call(actor: actor)
    end
  end
end
