# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StandardErrorRescueInventoryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  REVIEWED_RESCUES = {
    "app/controllers/concerns/actor_support.rb" => {
      count: 5,
      classification: "auth boundary; each rescue logs and re-raises ActorSupport::ResolutionError",
    },
    "app/controllers/concerns/authentication_logoutable.rb" => {
      count: 5,
      classification: "logout boundary; each rescue logs and re-raises after session cleanup",
    },
    "app/controllers/concerns/social_callback_guard.rb" => {
      count: 1,
      classification: "callback boundary; clears state and re-raises",
    },
    "app/controllers/concerns/social_omniauth_callback_flow.rb" => {
      count: 1,
      classification: "callback boundary; clears intent and re-raises",
    },
    "app/controllers/concerns/authentication_audit_writer.rb" => {
      count: 4,
      classification: "best-effort audit side effect with outbox/fallback recovery",
    },
    "app/controllers/concerns/authorization_audit.rb" => {
      count: 1,
      classification: "best-effort authorization failure audit side effect",
    },
    "app/controllers/concerns/preference_adoption.rb" => {
      count: 2,
      classification: "best-effort preference adoption side effect",
    },
    "app/controllers/concerns/preference_base.rb" => {
      count: 2,
      classification: "preference token/cookie degradation; auth state must not depend on this",
    },
    "app/controllers/concerns/preference_core.rb" => {
      count: 1,
      classification: "preference persistence side effect; resolution errors are re-raised separately",
    },
    "app/controllers/concerns/preference_resource_sync.rb" => {
      count: 1,
      classification: "preference resource sync side effect; resolution errors are re-raised separately",
    },
    "app/controllers/concerns/preference_transport.rb" => {
      count: 1,
      classification: "preference refresh transport side effect; resolution errors are re-raised separately",
    },
    "app/controllers/concerns/authentication_base.rb" => {
      count: 5,
      classification: "mixed legacy inventory; each site needs follow-up before changing behavior",
    },
    "app/controllers/concerns/passkey_sign_in_flow.rb" => {
      count: 2,
      classification: "WebAuthn options error response and best-effort risk emission boundaries",
    },
    "app/controllers/auth/app/sign/in/secrets_controller.rb" => {
      count: 2,
      classification: "secret_credential sign-in error response boundary; follow-up required",
    },
    "app/controllers/auth/com/sign/in/secrets_controller.rb" => {
      count: 1,
      classification: "secret_credential sign-in error response boundary; follow-up required",
    },
    "app/controllers/auth/org/sign/in/secrets_controller.rb" => {
      count: 1,
      classification: "secret_credential sign-in error response boundary; follow-up required",
    },
  }.freeze

  test "reviewed StandardError rescues stay classified" do
    offenders =
      REVIEWED_RESCUES.filter_map do |path, expected|
        actual = rescue_count(path)
        next if actual == expected.fetch(:count) && expected.fetch(:classification).present?

        "#{path}: expected #{expected.fetch(:count)}, got #{actual} (#{expected.fetch(:classification)})"
      end

    assert_empty offenders, "Reviewed StandardError rescue inventory changed:\n#{offenders.join("\n")}"
  end

  private

  def rescue_count(path)
    Rails.root.join(path).read.scan(/\brescue\s+StandardError\b/).size
  end
end
