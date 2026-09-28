# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAppVerificationPasskeysControllerCoverageTest < ActiveSupport::TestCase
  class Harness < Auth::App::Verification::PasskeysController
    def initialize
      super
      @params_hash = { ri: "tokyo" }
      @errors = ["bad"]
      @passkey_challenge_id = "challenge-1"
      @passkey_request_options = { challenge: "abc" }
    end

    def params = ActionController::Parameters.new(@params_hash)

    def t(key, **)
      I18n.t(key, **)
    end

    def incoming_scope
      "settings"
    end

    def incoming_pt
      "pt-token"
    end

    def auth_app_verification_passkey_path(**kwargs)
      "/verification/passkey?#{kwargs.to_query}"
    end

    def auth_app_verification_path(**kwargs)
      "/verification?#{kwargs.to_query}"
    end

    def auth_app_verification_cancellation_path(**kwargs)
      "/verification/cancellation?#{kwargs.to_query}"
    end

    def form_authenticity_token
      "csrf"
    end
  end

  test "new and create stop when a step-up session is missing" do
    harness = Harness.new
    harness.define_singleton_method(:require_step_up_session!) { false }

    assert_nil harness.new
    assert_nil harness.create
  end

  test "create renders the inertia page when passkey verification fails" do
    harness = Harness.new
    rendered = []
    harness.define_singleton_method(:require_step_up_session!) { true }
    harness.define_singleton_method(:redirect_if_recent_verification_for_post!) { false }
    harness.define_singleton_method(:require_method_available!) { |_method| true }
    harness.define_singleton_method(:verify_passkey!) { false }
    harness.define_singleton_method(:record_failed_step_up_attempt!) { |_method| true }
    harness.define_singleton_method(:prepare_passkey_challenge!) { true }
    harness.define_singleton_method(:render) { |**kwargs| rendered << kwargs }

    harness.create

    assert_equal Auth::App::Verification::PasskeysController::NEW_COMPONENT, rendered.last[:inertia]
    assert_equal :unprocessable_content, rendered.last[:status]
  end

  test "new renders the inertia page after issuing a challenge" do
    harness = Harness.new
    rendered = []
    harness.define_singleton_method(:require_step_up_session!) { true }
    harness.define_singleton_method(:redirect_if_recent_verification_for_get!) { false }
    harness.define_singleton_method(:require_method_available!) { |_method| true }
    harness.define_singleton_method(:prepare_passkey_challenge!) { true }
    harness.define_singleton_method(:render) { |**kwargs| rendered << kwargs }

    harness.new

    assert_equal Auth::App::Verification::PasskeysController::NEW_COMPONENT, rendered.last[:inertia]
  end
end
