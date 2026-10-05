# typed: false
# frozen_string_literal: true

require "test_helper"

# Telephone list, form, and removal pages on the app identity surface,
# including the contactability guard that refuses to remove the last way of
# reaching the client.
class Base::App::Identity::TelephonesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_telephone_statuses, :client_email_statuses,
           :client_token_kinds, :client_token_statuses, :client_token_binding_methods,
           :client_token_dbsc_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @user = clients(:one)
    @token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
    _verification, raw_verification = ClientVerification.issue_for_token!(token: @token)
    cookies[ClientVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_telephone",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
    )
    access_token = AuthenticationToken.encode(
      @user, host: @host, session_public_id: @token.public_id,
             resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    @headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
  end

  test "index lists the telephones owned by the signed-in client" do
    telephone = @user.client_telephones.create!(
      raw_number: "+15558675401", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    get base_app_identity_telephones_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    listed = inertia_props.fetch("telephones").pluck("public_id")

    assert_includes listed, telephone.public_id
    assert_equal new_base_app_identity_telephone_path(ri: "jp"), inertia_props.dig("new_link", "href")
    assert_equal new_base_app_identity_telephones_registration_path(ri: "jp"),
                 inertia_props.dig("registration_link", "href")
  end

  test "index does not list another client's telephones" do
    other = clients(:two)
    other_telephone = other.client_telephones.create!(
      raw_number: "+15558675402", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    get base_app_identity_telephones_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    listed = inertia_props.fetch("telephones").pluck("public_id")

    assert_not_includes listed, other_telephone.public_id
  end

  test "new renders the telephone form" do
    get new_base_app_identity_telephone_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_equal I18n.t("sign.app.settings.telephone.new.title"), inertia_props.fetch("title")
  end

  test "edit renders the removal page for a telephone the client owns" do
    telephone = @user.client_telephones.create!(
      raw_number: "+15558675403", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    get edit_base_app_identity_telephone_url(telephone.public_id, ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_equal telephone.number.to_s, inertia_props.fetch("number")
  end

  test "edit answers not found for a telephone owned by another client" do
    other_telephone = clients(:two).client_telephones.create!(
      raw_number: "+15558675404", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    get edit_base_app_identity_telephone_url(other_telephone.public_id, ri: "jp", host: @host), headers: @headers

    assert_response :not_found
  end

  test "create starts telephone verification and moves on to the registration step" do
    number = "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"

    post base_app_identity_telephones_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: number } },
         headers: @headers

    assert_response :see_other
    assert_redirected_to edit_base_app_identity_telephones_registration_url(ri: "jp", host: @host)
  end

  test "create re-renders the form when the number cannot be verified" do
    post base_app_identity_telephones_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "not-a-telephone-number" } },
         headers: @headers

    assert_response :unprocessable_content
  end

  test "destroy removes the telephone while another verified contact remains" do
    @user.client_emails.create!(
      raw_address: "telephone_removal_contact@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    telephone = @user.client_telephones.create!(
      raw_number: "+15558675405", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    assert_difference("ClientTelephone.count", -1) do
      delete base_app_identity_telephone_url(telephone.public_id, ri: "jp", host: @host), headers: @headers
    end

    assert_redirected_to base_app_identity_telephones_path(ri: "jp")
  end

  test "destroy refuses to remove the client's only remaining contact method" do
    @user.client_emails.destroy_all
    telephone = @user.client_telephones.create!(
      raw_number: "+15558675406", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    assert_no_difference("ClientTelephone.count") do
      delete base_app_identity_telephone_url(telephone.public_id, ri: "jp", host: @host), headers: @headers
    end

    assert_redirected_to base_app_identity_telephones_path(ri: "jp")
  end
end
