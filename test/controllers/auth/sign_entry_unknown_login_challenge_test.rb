# typed: false
# frozen_string_literal: true

require "test_helper"

# The sign-in and sign-up entry pages accept a non-secret Base admission reference on GET and
# redeem it only on the CSRF-protected POST. A reference that names nothing is a caller error, not
# a server error: each surface answers 400 rather than letting the lookup escape as a 500, and none
# of them starts a session for it.
class AuthSignEntryUnknownLoginChallengeTest < ActionDispatch::IntegrationTest
  ENTRY_POINTS = {
    "app sign-in" => ["PUBLIC_AUTH_SERVICE_URL", :auth_app_sign_in_url],
    "app sign-up" => ["PUBLIC_AUTH_SERVICE_URL", :auth_app_sign_up_url],
    "com sign-in" => ["PUBLIC_AUTH_CORPORATE_URL", :auth_com_sign_in_url],
    "com sign-up" => ["PUBLIC_AUTH_CORPORATE_URL", :auth_com_sign_up_url],
    "org sign-in" => ["PUBLIC_AUTH_STAFF_URL", :auth_org_sign_in_url],
    "org sign-up" => ["PUBLIC_AUTH_STAFF_URL", :auth_org_sign_up_url],
  }.freeze

  ENTRY_POINTS.each do |label, (env_name, helper)|
    test "#{label} refuses an admission reference that names no transaction" do
      host = ENV.fetch(env_name)

      redeem_auth_ceremony_entry!(
        public_send(helper), reference: "no-such-challenge",
                             params: { ri: "jp" }, headers: { "Host" => host },
      )

      assert_response :bad_request
      assert_equal I18n.t("errors.messages.invalid_request"), response.body
      assert_nil session[:oidc_authorization_login_challenge]
    end
  end
end
