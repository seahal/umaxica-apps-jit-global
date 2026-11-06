# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/rp_cell_sign_out_helper"

class Core::App::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  include RpCellSessionHelper
  include RpCellSignOutHelper

  fixtures :clients, :client_token_kinds

  setup do
    host! ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    https!
  end

  test "RP cookie sign out renders confirmation without mutation" do
    actor, root_token = client_actor_and_root_token
    authenticate_rp_cell_for_sign_out!(client_id: "core-app-jp", actor:, root_token:)

    get edit_core_app_sign_out_url(ri: "jp")

    assert_response :success
    assert_equal "strict-origin", response.headers["Referrer-Policy"]
    assert_select "form[action*=?][method=?]", core_app_sign_out_path, "post"
    assert_select "form[action='#{core_app_sign_out_path}'] input[name=_method][value=delete]", count: 0
    assert_predicate root_token.reload, :currently_usable?
    assert_predicate @rp_cell_session.reload, :active?
  end

  test "sign-out launch revokes only its local RP session before the no-hint Visa handoff" do
    actor, root_token = client_actor_and_root_token
    authenticate_rp_cell_for_sign_out!(client_id: "core-app-jp", actor:, root_token:)
    op_grant_count = OpAppGrant.count

    post_rp_cell_sign_out(core_app_sign_out_url(ri: "jp"))

    assert_rp_cell_sign_out_handoff!(client_id: "core-app-jp", region: "jp")
    assert_equal op_grant_count, OpAppGrant.count
    assert_nil response.headers["Clear-Site-Data"]
    assert_nil @rp_cell_revocation_calls.fetch(0)[:id_token_hint]
  end

  test "confirmation page does not clear site data" do
    get edit_core_app_sign_out_url(ri: "jp")

    assert_response :success
    assert_nil response.headers["Clear-Site-Data"]
  end

  test "sign-out without a Refresh Token still ends the local session without sending a revocation" do
    actor, root_token = client_actor_and_root_token
    authenticate_rp_cell_for_sign_out!(client_id: "core-app-jp", actor:, root_token:)
    cookies.delete(OidcRpBrowserCredentialContract::REFRESH_COOKIE)

    post_rp_cell_sign_out(core_app_sign_out_url(ri: "jp"))

    assert_response :see_other
    assert_predicate @rp_cell_session.reload.revoked_at, :present?
    assert_empty @rp_cell_revocation_calls
    assert_predicate @rp_cell_op_grant.reload, :active?
  end

  test "sign-out completion uses the default region when the request region is unsupported" do
    actor, root_token = client_actor_and_root_token
    authenticate_rp_cell_for_sign_out!(client_id: "core-app-jp", actor:, root_token:)

    post_rp_cell_sign_out(core_app_sign_out_url(ri: "xx"))

    assert_rp_cell_sign_out_handoff!(client_id: "core-app-jp", region: RequestContextContract.default_region)
  end

  test "sign-out completion uses the requested US region" do
    actor, root_token = client_actor_and_root_token
    authenticate_rp_cell_for_sign_out!(client_id: "core-app-jp", actor:, root_token:)

    post_rp_cell_sign_out(core_app_sign_out_url(ri: "us"))

    assert_rp_cell_sign_out_handoff!(client_id: "core-app-jp", region: "us")
  end

  test "sign-out completion uses the default region when none is supplied" do
    actor, root_token = client_actor_and_root_token
    authenticate_rp_cell_for_sign_out!(client_id: "core-app-jp", actor:, root_token:)

    post_rp_cell_sign_out(core_app_sign_out_url)

    assert_rp_cell_sign_out_handoff!(client_id: "core-app-jp", region: RequestContextContract.default_region)
  end

  test "a sibling RP local session cannot authorize sign-out on this cell" do
    actor, root_token = client_actor_and_root_token
    _token_response, _payload, sibling_session = sign_in_rp_cell("warp-app-jp", actor:, root_token:)
    @rp_cell_session = sibling_session

    post_rp_cell_sign_out(core_app_sign_out_url(ri: "jp"))

    assert_response :unauthorized
    assert_empty @rp_cell_revocation_calls
    assert_predicate sibling_session.reload, :active?
    assert_predicate root_token.reload, :currently_usable?
  end

  test "root Browser Session and bearer credentials do not replace an RP local session" do
    actor, root_token = client_actor_and_root_token
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = root_token.rotate_refresh_token!

    post_rp_cell_sign_out(
      core_app_sign_out_url(ri: "jp"), headers: bearer_headers(
        jwt_access_token_for(actor, session_public_id: root_token.public_id, resource_type: "client"),
      ),
    )

    assert_response :unauthorized
    assert_predicate root_token.reload, :currently_usable?
    assert_empty @rp_cell_revocation_calls
  end

  test "sign-out redirects directly to Visa and does not send an ID Token hint" do
    actor, root_token = client_actor_and_root_token
    authenticate_rp_cell_for_sign_out!(client_id: "core-app-jp", actor:, root_token:)

    post_rp_cell_sign_out(core_app_sign_out_url(ri: "jp"))

    assert_rp_cell_sign_out_handoff!(client_id: "core-app-jp", region: "jp")
    assert_equal ENV.fetch("PUBLIC_VISA_SERVICE_URL"), URI.parse(response.location).host
    assert_not_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), URI.parse(response.location).host
  end

  private

  def client_actor_and_root_token
    actor = clients(:one)
    root_token = ClientToken.create!(
      authentication_epoch: 0, user: actor, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    [actor, root_token]
  end

  def bearer_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
