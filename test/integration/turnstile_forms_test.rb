# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class TurnstileFormsTest < ActionDispatch::IntegrationTest
  def setup
    # Map of paths that contain Turnstile forms with turbo disabled
    # Format: [Host ENV Name, Path, Description]
    @turnstile_form_paths = [
      { name: "Sign::App registration email", env_key: "PUBLIC_AUTH_SERVICE_URL", path: "/sign/up/email/new" },
      { name: "Sign::App authentication email", env_key: "PUBLIC_AUTH_SERVICE_URL", path: "/sign/in/email/new" },
      # { name: "Sign::Org registration emails", env_key: "PRIVATE_AUTH_STAFF_URL", path: "/registration/emails/new" },
      # { name: "Sign::Org registration passkeys",
      #   env_key: "PRIVATE_AUTH_STAFF_URL", path: "/registration/passkeys/new" },
    ]
  end

  test "all Turnstile forms have turbo disabled" do
    @turnstile_form_paths.each do |form_config|
      name = form_config[:name]
      env_key = form_config[:env_key]
      path = form_config[:path]

      host = ENV.fetch(env_key)

      host! host
      https!
      intent = path.include?("/sign/up/") ? "sign_up" : "sign_in"
      nonce = SecureRandom.urlsafe_base64(32)
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: "app", intent: intent, base_browser_nonce: nonce, base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
      attached, raw_sid = ClientAuthCeremonySession.issue!
      binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
      binding.confirm_base!(
        base_token: nil, browser_digest: AuthAdmissionBinding.browser_digest(
          surface: "app", entry_ref: issuance.reference, nonce: nonce,
        ),
      )
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: "app", expected_intent: intent, binding: binding,
        raw_auth_sid: raw_sid,
      )
      admitted, admitted_sid = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "local_#{intent}", previous_raw_sid: raw_sid,
        local_sign_in_flow_ref: issuance.transaction.public_id,
      )
      binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
      cookies[JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"] = admitted_sid
      phase_binding =
        if intent == "sign_in"
          SignInFlowBindingCodec.encode(flow: issuance.transaction, surface: "app", phase: "PRIMARY_PENDING")
        end
      get path, params: (phase_binding ? { fb: phase_binding } : {}), headers: form_config[:headers] || {}

      if response.redirect?
        follow_redirect!
      end

      assert_response :success, "Failed to access #{path} for #{name} (#{host})"

      turnstile = inertia_props["turnstile"]

      assert_predicate turnstile, :present?, "Expected Turnstile props for #{name}"

      # The widget is drawn into the form rather than executed in the background, which is what
      # kept these forms on a plain document submit instead of a background visit.
      assert_equal "render", turnstile.fetch("mode"),
                   "Expected an in-form Turnstile widget in #{name} (#{host})"
    end
  end

  test "Turnstile widget is rendered" do
    @turnstile_form_paths.each do |form_config|
      name = form_config[:name]
      env_key = form_config[:env_key]
      path = form_config[:path]

      host = ENV.fetch(env_key)

      host! host
      https!
      intent = path.include?("/sign/up/") ? "sign_up" : "sign_in"
      nonce = SecureRandom.urlsafe_base64(32)
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: "app", intent: intent, base_browser_nonce: nonce, base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
      attached, raw_sid = ClientAuthCeremonySession.issue!
      binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
      binding.confirm_base!(
        base_token: nil, browser_digest: AuthAdmissionBinding.browser_digest(
          surface: "app", entry_ref: issuance.reference, nonce: nonce,
        ),
      )
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: "app", expected_intent: intent, binding: binding,
        raw_auth_sid: raw_sid,
      )
      admitted, admitted_sid = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "local_#{intent}", previous_raw_sid: raw_sid,
        local_sign_in_flow_ref: issuance.transaction.public_id,
      )
      binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
      cookies[JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"] = admitted_sid
      phase_binding =
        if intent == "sign_in"
          SignInFlowBindingCodec.encode(flow: issuance.transaction, surface: "app", phase: "PRIMARY_PENDING")
        end
      get path, params: (phase_binding ? { fb: phase_binding } : {}), headers: form_config[:headers] || {}

      if response.redirect?
        follow_redirect!
      end

      assert_response :success, "Failed to access #{path} for #{name} (#{host})"

      # The widget mounts from the props the server sends it, so the site key is what "the page
      # renders a Turnstile challenge" means now.
      assert_predicate inertia_props.fetch("turnstile").fetch("site_key"), :present?,
                       "Expected Turnstile widget in #{name} (#{host})"
    end
  end
end
