# frozen_string_literal: true

# Builds the two-sided proof required by BaseAuthAdmissionCoordinator's public
# entry-reference consumer. The helper deliberately returns the raw ceremony
# sid only to the test caller; production templates and URLs never carry it.
module AuthAdmissionBindingTestHelper
  def issue_base_step_up_admission!(**attributes)
    attributes[:base_browser_nonce] ||= "test-browser-nonce"
    attributes[:base_token] ||= attributes.fetch(:token)
    BaseStepUpAdmissionIssuer.call!(**attributes)
  end

  def issue_confirmed_base_step_up_admission!(**attributes)
    nonce = attributes[:base_browser_nonce] || "test-browser-nonce"
    token = attributes[:base_token] || attributes.fetch(:token)
    issuance = issue_base_step_up_admission!(**attributes)
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: issuance.transaction.surface, reference: issuance.reference,
    )
    auth_session, raw_sid = binding.class.auth_admission_session_class.issue!
    binding.attach_auth_session!(auth_session:, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: token,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: issuance.transaction.surface, entry_ref: issuance.reference, nonce: nonce,
      ),
    )
    if respond_to?(:cookies, true)
      auth_host =
        case issuance.transaction.surface
        when "app" then ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        when "com" then ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        when "org" then ENV.fetch("PUBLIC_AUTH_STAFF_URL")
        else raise ArgumentError, "unsupported Auth ceremony surface"
        end
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      cookies.merge(
        "#{cookie_name}=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{auth_host}/"),
      )
    end
    issuance
  end

  def prepare_admission_binding_for_consumption!(admission_binding, base_token:,
                                                 base_browser_nonce: "test-browser-nonce")
    auth_session, raw_sid = admission_binding.class.auth_admission_session_class.issue!
    admission_binding.attach_auth_session!(auth_session:, confirmation_ref: SecureRandom.uuid)
    browser_digest = AuthAdmissionBinding.browser_digest(
      surface: admission_binding.class.auth_admission_surface_name,
      entry_ref: admission_binding.entry_ref,
      nonce: base_browser_nonce,
    )
    admission_binding.confirm_base!(base_token:, browser_digest:)
    [auth_session, raw_sid]
  end
end
