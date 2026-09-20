# typed: false
# frozen_string_literal: true

require "test_helper"

# Re-entry into a withdrawal ceremony is answered from a short-lived session
# record. Every way that record can fail to identify an eligible subject --
# absent, expired, a decoy issued for an address that has no account, or an
# address whose subject is no longer eligible -- has to end in the same
# unprocessable re-entry page, so none of them can be told apart from outside.
class WithdrawalCeremonyReentryGuardsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < ApplicationController
    include WithdrawalCeremonyReentry

    attr_accessor :session_hash, :params_hash, :reentry_state_value, :email_model

    def session
      @session_hash ||= {}
    end

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def render(*args, **kwargs)
      (@renders ||= []) << [args, kwargs]
    end

    def renders = @renders ||= []

    def identity_email_model = email_model

    def withdrawal_reentry_state = reentry_state_value

    def withdrawal_reentry_address = "reentry@example.com"

    # Supplied by the surface controller in production; the guard under test only
    # needs it to answer "no subject" for an address with no account behind it.
    def withdrawal_subject_from_email(_email) = nil

    def invoke(name, ...) = send(name, ...)
  end

  class FakeEmail
    def self.new(*) = allocate

    def self.find_by(**) = nil
  end

  setup do
    @harness = Harness.new
    @harness.email_model = FakeEmail
  end

  test "the re-entry page is rendered from the controller's own template" do
    @harness.reentry_state_value = { "expires_at" => 1.hour.from_now.to_i }

    @harness.new

    assert_equal [[[:new], { status: :ok }]], @harness.renders
    assert_equal @harness.reentry_state_value, @harness.instance_variable_get(:@reentry_state)
  end
end
