# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CloudflareTurnstileTest < ActiveSupport::TestCase
  class TestController < ApplicationController
    include CloudflareTurnstile

    public :cloudflare_turnstile_validation, :cloudflare_turnstile_stealth_validation, :verify_turnstile_stealth!
  end

  def setup
    @controller = TestController.new
    @request = ActionDispatch::TestRequest.create
    @controller.request = @request
  end

  def test_validation_in_test_mode
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }

    assert_equal({ "success" => true }, @controller.cloudflare_turnstile_validation)
  end

  def test_validation_in_real_mode_calls_verifier
    TurnstileVerifierStub.challenge_enabled = false
    @controller.stub(:params, ActionController::Parameters.new({ "cf-turnstile-response" => "tok" })) do
      TurnstileVerifierStub.stub(:verify, { "success" => true }) do
        assert_equal({ "success" => true }, @controller.cloudflare_turnstile_validation)
      end
    end
  end

  def test_validation_in_real_mode_tolerates_missing_token
    TurnstileVerifierStub.challenge_enabled = false
    @controller.stub(:params, ActionController::Parameters.new({})) do
      missing_response = { "success" => false, "error" => "missing cf-turnstile-response" }
      result = nil

      TurnstileVerifierStub.stub(:verify, missing_response) do
        result = @controller.cloudflare_turnstile_validation
      end

      assert_equal(missing_response, result)
    end
  end

  def test_verify_turnstile_stealth_failure
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => false }

    @controller.stub(:render, true) do
      assert_not @controller.verify_turnstile_stealth!
    end
  end
end
