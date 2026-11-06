# frozen_string_literal: true

require "test_helper"

class SensitiveAdmissionPersistenceTest < ActiveSupport::TestCase
  test "realm specific admission validates its provider, deadline and browser binding" do
    [
      [ClientSensitiveAdmission, "app", "base-app-ww"],
      [OperatorSensitiveAdmission, "org", "base-org-ww"],
    ].each do |model, realm, client_id|
      now = Time.current.change(usec: 0)
      admission = model.new(
        public_ref: PublicId.generate, secret_digest: "a" * 64, realm: realm, client_id: client_id,
        actor_subject: "subject", grant_sid: "grant", rp_session_ref: "session",
        browser_binding_digest: "b" * 64, purpose: "passkey_registration", provider: "none",
        event_jti: SecureRandom.uuid, event_auth_time: now.to_i, issued_at: now, expires_at: now + 1.minute,
        status: "issued",
      )

      assert_predicate admission, :valid?
      admission.provider = "google"

      assert_not admission.valid?
      admission.provider = "none"
      admission.expires_at = now

      assert_not admission.valid?
      admission.expires_at = now + 1.minute
      admission.browser_binding_digest = "missing"

      assert_not admission.valid?
      admission.browser_binding_digest = "b" * 64
      admission.status = "unknown"

      assert_not admission.valid?
    end
  end
end
