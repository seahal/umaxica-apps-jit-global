# typed: false
# frozen_string_literal: true

require "test_helper"

# These concerns are written as templates: the surface that includes one supplies
# the per-surface seams, and a surface that forgets one must fail loudly at the
# seam rather than answering nil into something far away. Each seam declared with
# NotImplementedError is exercised here so the contract cannot quietly disappear.
class SurfaceSeamContractsTest < ActiveSupport::TestCase
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  self.fixture_table_names = []

  # The concerns register callbacks and helpers when included; a plain object has
  # neither, so the harness answers those class-level calls itself.
  def self.harness_for(concern)
    Class.new do
      class << self
        def before_action(*, **, &) = nil

        def after_action(*, **, &) = nil

        def helper_method(*) = nil

        def rate_limit(*, **, &) = nil

        def rate_limit_store = nil

        def skip_before_action(*, **, &) = nil
      end

      include concern

      def invoke(name, ...) = send(name, ...)
    end
  end

  SEAMS = {
    CoreBrowserApiBoundary => [
      [:core_actor_tld], [:core_resource_class], [:core_token_class], [:core_resource_type],
    ],
    McpEndpoint => [[:mcp_surface_identity]],
    OidcSsoInitiator => [[:oidc_client_id], [:oidc_sign_host], [:oidc_base_authority_host]],
    PasskeyRegistrationFlow => [
      [:recovery_passcode_top_up_actor], [:recovery_passcode_top_up_credential_class],
      [:recovery_passcode_reveal_redirect_url, "token"],
    ],
    PasskeySignInFlow => [
      [:find_active_passkey_actor, "identifier"], [:perform_passkey_sign_in, :passkey],
      [:render_passkey_restricted_success, {}], [:passkey_checkpoint_redirect_url],
      [:passkey_default_redirect_url],
    ],
    SessionLimitPendingGuard => [[:pending_session_limit_redirect_path]],
    SignRequiresRecoveryPasscodes => [
      [:recovery_passcode_requirement_actor], [:recovery_passcode_requirement_credential_class],
      [:recovery_passcode_setup_url],
    ],
    SignSettingsSecretCredentialTurnstileGuard => [
      [:prepare_secret_credential_turnstile_create_failure],
      [:render_secret_credential_turnstile_create_failure],
    ],
    SignVerificationAuditAndCookie => [
      [:verification_audit_event_class], [:verification_audit_level_class],
      [:verification_default_activity_level_id], [:verification_activity_model],
      [:current_verification_actor], [:verification_actor_type],
    ],
    SignVerificationCancellation => [[:verification_cancellation_fallback_path]],
    SignVerificationCommonBase => [[:verification_unavailable_redirect_path]],
    SignVerificationEntry => [[:verification_success_notice_key]],
    SignVerificationPasskeyChecks => [
      [:verification_passkeys_scope], [:verification_passkey_model],
      [:passkey_actor_matches?, :passkey], [:verification_no_passkey_i18n_key],
    ],
    SignVerificationStepUpLifecycle => [
      [:valid_step_up_session?, {}], [:handle_invalid_step_up_session!], [:clear_step_up_state!],
      [:verification_model], [:verification_success_event_id], [:verification_success_notice_key],
      [:verification_success_fallback_path],
    ],
    SignVerificationTotpChecks => [[:active_totp_credentials]],
    SocialCeremonyEntry => [
      [:social_ceremony_surface], [:social_ceremony_providers], [:social_ceremony_abort_path],
    ],
  }.freeze

  test "the external authentication ports declare their single call seam" do
    [
      ExternalAuthentication::AppleClientSecretProviderPort,
      ExternalAuthentication::AppleNotificationVerifierPort,
    ].each do |port|
      assert_raises(NotImplementedError, port.name) { Class.new { include port }.new.call }
    end

    revocation = Class.new { include ExternalAuthentication::AppleCredentialRevocationPort }.new

    assert_raises(NotImplementedError) { revocation.call(refresh_token: "rt") }
  end
end
