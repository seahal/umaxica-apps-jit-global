# frozen_string_literal: true

require "test_helper"
require_relative "../support/browser_rp_logout_flow_helper"

# AT-002 / AT-009 partitions for the Browser RP sign-out binding: root family and generation,
# safe methods, CSRF, the 10-minute intent expiry, intent reuse and the proof parameter.
class OidcRpLogoutBindingPartitionsTest < ActionDispatch::IntegrationTest
  include BrowserRpLogoutFlowHelper

  setup do
    @core_host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    https!
    @user = clients(:one)
    @root_token = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    @core_session = create_rp_session("core-app-jp")
  end

  test "a legitimately rotated root of the same Device Session and family is accepted" do
    challenge, origin_cookie = start_sign_out
    @root_token.rotate_refresh_token!

    confirm_at_authority(challenge, origin_cookie)

    assert_response :see_other
    assert_not_predicate @root_token.reload, :currently_usable?
    assert_predicate @core_session.reload, :revoked?
  end

  test "a root from a different refresh family revokes nothing" do
    challenge, origin_cookie = start_sign_out
    @root_token.update_columns(refresh_token_family_id: SecureRandom.uuid)

    confirm_at_authority(challenge, origin_cookie)

    assert_idp_session_error_response
    assert_unchanged(challenge)
  end

  test "a regressed root generation revokes nothing" do
    challenge, origin_cookie = start_sign_out
    transaction = AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge)
    transaction.update_columns(captured_root_generation: @root_token.refresh_token_generation.to_i + 1)

    confirm_at_authority(challenge, origin_cookie)

    assert_idp_session_error_response
    assert_unchanged(challenge)
  end

  test "an IdP session on another device of the same actor revokes neither parent" do
    challenge, origin_cookie = start_sign_out
    other_device_root = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )

    confirm_at_authority(challenge, origin_cookie, headers: base_authority_headers(root_token: other_device_root))

    assert_idp_session_error_response
    assert_unchanged(challenge)
    assert_predicate other_device_root.reload, :currently_usable?
  end

  test "a substituted session identifier never selects another session" do
    challenge, origin_cookie = start_sign_out
    other_root = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    other_session = create_rp_session("warp-app-jp", root_token: other_root)

    confirm_at_authority(
      challenge, origin_cookie,
      params: { session_ref: other_session.public_id, sid: other_root.device_session_record.public_id },
    )

    assert_response :see_other
    assert_not_predicate @root_token.reload, :currently_usable?
    assert_predicate other_root.reload, :currently_usable?
    assert_predicate other_session.reload, :active?
  end

  test "GET and HEAD on initiation and confirmation change no row" do
    challenge, origin_cookie = start_sign_out
    host!(@base_host)

    get base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"),
        headers: with_session_cookie(base_authority_headers, session_cookie: origin_cookie)

    assert_response :ok
    head base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"),
         headers: with_session_cookie(base_authority_headers, session_cookie: origin_cookie)
    host!(@core_host)
    head core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp")

    assert_unchanged(challenge)
  end

  test "a confirmation without a valid CSRF token is refused before any effect" do
    challenge, origin_cookie = start_sign_out
    ActionController::Base.allow_forgery_protection = true

    confirm_at_authority(challenge, origin_cookie, params: { authenticity_token: "forged" })

    assert_includes [400, 403, 422], response.status
    assert_unchanged(challenge)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "a cross-site confirmation is refused before any effect" do
    challenge, origin_cookie = start_sign_out
    ActionController::Base.allow_forgery_protection = true
    host!(@base_host)

    post(
      base_app_oidc_logout_path(logout_challenge: challenge, ri: "jp"),
      headers: with_session_cookie(
        base_authority_headers.merge("Origin" => "https://attacker.invalid", "Sec-Fetch-Site" => "cross-site"),
        session_cookie: origin_cookie,
      ),
    )

    assert_not_equal 303, response.status
    assert_unchanged(challenge)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "a confirmation one second before the 10-minute intent expiry commits" do
    challenge, origin_cookie = start_sign_out
    expires_at = whole_second_expiry(challenge)

    assert_in_delta 10.minutes.from_now.to_f, expires_at.to_f, 5.0

    travel_to(expires_at - 1.second) { confirm_at_authority(challenge, origin_cookie) }

    assert_response :see_other
    assert_not_predicate @root_token.reload, :currently_usable?
  end

  test "a confirmation at the 10-minute intent expiry revokes nothing" do
    challenge, origin_cookie = start_sign_out
    expires_at = whole_second_expiry(challenge)

    travel_to(expires_at) { confirm_at_authority(challenge, origin_cookie) }

    assert_not_equal 303, response.status
    assert_unchanged(challenge)
  end

  test "a confirmation after the 10-minute intent expiry revokes nothing" do
    challenge, origin_cookie = start_sign_out
    expires_at = whole_second_expiry(challenge)

    travel_to(expires_at + 1.second) { confirm_at_authority(challenge, origin_cookie) }

    assert_not_equal 303, response.status
    assert_unchanged(challenge)
  end

  test "a COMMIT just before expiry stays committed while the expired origin continuation refuses safely" do
    challenge, origin_cookie = start_sign_out
    expires_at = whole_second_expiry(challenge)
    travel_to(expires_at - 1.second) { confirm_at_authority(challenge, origin_cookie) }
    host!(@core_host)

    travel_to(expires_at + 1.second) do
      post core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp"),
           headers: with_session_cookie(origin_headers("same-origin"), session_cookie: origin_cookie)
    end

    assert_not_equal 303, response.status
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.unavailable_title")
    assert_not_predicate @root_token.reload, :currently_usable?
    assert_predicate @core_session.reload, :revoked?
  end

  test "starting again from the same RP session reuses its unfinished intent" do
    first_challenge, = start_sign_out
    second_challenge, = start_sign_out

    assert_equal first_challenge, second_challenge
  end

  test "an intent of another RP session or another browser is never reused" do
    first_challenge, = start_sign_out
    other_root = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    other_rp_challenge, = start_sign_out(
      create_rp_session("core-app-jp", root_token: other_root),
      root_token: other_root,
    )
    reset!
    https!
    other_browser_challenge, = start_sign_out

    assert_not_equal first_challenge, other_rp_challenge
    assert_not_equal first_challenge, other_browser_challenge
  end

  test "the intent proof is filtered from logs and never appears in a redirect URL" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("logout_intent_proof" => "raw-proof").fetch("logout_intent_proof")

    challenge, origin_cookie = start_sign_out
    locations = [response.location]
    confirm_at_authority(challenge, origin_cookie)
    locations << response.location
    host!(@core_host)
    get core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp")
    post core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp"),
         params: response_form_params,
         headers: with_session_cookie(origin_headers("same-origin"), session_cookie: origin_cookie)
    locations << response.location

    assert_equal 3, locations.compact.size
    locations.each { |location| assert_not_includes location, "logout_intent_proof" }
  end

  private

  # travel_to drops sub-second precision, so the stored expiry is aligned to a whole second to make
  # "at the expiry" exact.
  def whole_second_expiry(challenge)
    transaction = AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge)
    transaction.update_columns(expires_at: transaction.expires_at.change(usec: 0))
    transaction.reload.expires_at
  end

  def assert_unchanged(challenge)
    assert_predicate @root_token.reload, :currently_usable?
    assert_predicate @core_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
                 AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge).expected_step
  end
end
