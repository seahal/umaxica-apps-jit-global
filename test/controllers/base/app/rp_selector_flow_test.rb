# frozen_string_literal: true

require "test_helper"

class Base::App::RpSelectorFlowTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @actor = create_actor
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    https!
    @cell = RpCellBinding.for_client("base-app-ww")
    @issuer = OidcIssuer.for_resource_type("client")
    @subject = OidcSubject.for(@actor, resource_type: "client")
    @sid = SecureRandom.uuid
    enrollment = RpCallbackCommitter.call(
      cell: @cell,
      issuer: @issuer,
      subject: @subject,
      sid: @sid,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?

    @rp_session = enrollment.session
    @access_token, @jwks = issue_access_token
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = @access_token
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = @rp_session.public_id
  end

  test "RP session automatically selects its single candidate and opens dashboard" do
    with_rp_app_request do
      get "/dashboard?ri=jp"

      assert_redirected_to "/selector?ri=jp"

      get "/selector?ri=jp"

      assert_redirected_to "/dashboard?ri=jp"
      candidate = BaseSelectorAuthority.new(
        surface: :app,
        principal: @actor,
        session: @rp_session,
      ).selectable_candidates.fetch(0).fetch(:public)

      selection = RpBaseAppSessionSelection.find_by!(rp_session_id: @rp_session.id)

      assert_equal candidate.fetch(:account_public_id), selection.account_public_id

      avatar_result = AvatarAuthorityClient::Result.new(
        status: :ok,
        data: { "display_name" => "Selected persona", "image_version" => "test-image" },
        errors: {},
      )
      avatar_owner = Minitest::Mock.new
      avatar_owner.expect(:dashboard_identity, avatar_result, [])
      AvatarAuthorityClient.stub(
        :new,
        lambda { |**attributes|
          assert_equal @access_token, attributes.fetch(:access_token)
          assert_equal candidate.fetch(:account_public_id), attributes.fetch(:persona)
          assert_equal candidate.fetch(:organization_public_id),
                       attributes.fetch(:selection).collective_public_id
          assert_equal candidate.fetch(:organization_unit_public_id),
                       attributes.fetch(:selection).collective_unit_public_id
          assert_equal candidate.fetch(:avatar_public_id), attributes.fetch(:selection).avatar_public_id
          avatar_owner
        },
      ) do
        get "/dashboard?ri=jp"
      end

      assert_response :success
      assert_equal "base/app/dashboards/show", inertia_component
      identity = inertia_props.fetch("sections").first.fetch("current_identity")

      assert_equal "Selected persona", identity.fetch("display_name")
      assert_equal base_app_dashboard_avatar_image_path(ri: "jp", v: "test-image"),
                   identity.dig("avatar_image", "src")
      # Base shows the signed-in state without a link back to itself.
      assert_equal(
        [[I18n.t("layouts.shared.account_navigation.sign_out"), new_base_app_sign_out_path(ri: "jp")]],
        inertia_props.dig("chrome", "account_navigation", "links").map { |link| link.values_at("label", "href") },
      )
      assert_mock avatar_owner
      assert_not ClientToken.exists?(user: @actor)
      assert_not OpAppGrant.joins(:client_token).exists?(client_tokens: { user_id: @actor.id })
    end
  end

  test "RP selector refuses a persona owned by another actor" do
    other_actor = create_actor
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @actor)
    other_bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other_actor)
    other_candidate = BaseSelectorAuthority.new(
      surface: :app,
      principal: other_actor,
      session: nil,
    ).selectable_candidates.fetch(0).fetch(:public)

    with_rp_app_request do
      patch "/selector?ri=jp", params: other_candidate, as: :json

      assert_response :unprocessable_content
      assert_equal "invalid_selection", response.parsed_body.fetch("status")
      assert_not RpBaseAppSessionSelection.exists?(rp_session_id: @rp_session.id)
      assert_equal other_bootstrap.account.public_id, other_candidate.fetch(:account_public_id)
    end
  end

  test "RP switcher reads and writes the same local session selection" do
    with_rp_app_request do
      get "/selector?ri=jp"

      assert_redirected_to "/dashboard?ri=jp"
      candidate = BaseSelectorAuthority.new(
        surface: :app, principal: @actor, session: @rp_session,
      ).selectable_candidates.fetch(0).fetch(:public)
      selection = RpBaseAppSessionSelection.find_by!(rp_session_id: @rp_session.id)

      assert_equal candidate.fetch(:account_public_id), selection.account_public_id

      get "/switcher?ri=jp", as: :json

      assert_response :success
      assert_equal candidate.fetch(:account_public_id), response.parsed_body.dig("current", "account_public_id")

      patch "/switcher?ri=jp", params: {
        account_public_id: candidate.fetch(:account_public_id),
        organization_public_id: candidate.fetch(:organization_public_id),
        organization_unit_public_id: candidate.fetch(:organization_unit_public_id),
        avatar_public_id: candidate.fetch(:avatar_public_id),
      }, as: :json

      assert_response :success
      assert_equal "switched", response.parsed_body.fetch("status")
      assert_equal selection.id, RpBaseAppSessionSelection.find_by!(rp_session_id: @rp_session.id).id
      assert_not ClientToken.exists?(user: @actor)
    end
  end

  private

  def create_actor
    Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
  end

  def issue_access_token
    key = OpenSSL::PKey::EC.generate("secp384r1")
    now = Time.current.to_i
    token = JWT.encode(
      {
        "iss" => @issuer,
        "aud" => [@cell.client_id],
        "sub" => @subject,
        "sid" => @sid,
        "iat" => now,
        "nbf" => now - 1,
        "exp" => now + 300,
        "jti" => SecureRandom.uuid,
        "scope" => "openid",
        "client_id" => @cell.client_id,
        "authn_ctx" => "normal",
      },
      key,
      "ES384",
      { "kid" => "rp-selector-test", "typ" => "at+jwt" },
    )
    jwks = OidcOpJwksClient.new(
      jwks_uri: OidcIssuer.jwks_uri("client"),
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(key, kid: "rp-selector-test")] } },
    )
    [token, jwks]
  end

  def with_rp_app_request
    RuntimeRole.stub(:current, "rp-base-app-ww") do
      RuntimeRole.stub(:rp_browser_admission_open?, true) do
        OidcOpJwksClient.stub(:for_resource_type, @jwks) do
          OrgAdminAuthorityClient.stub(:new, ->(**) { flunk("APP selector must not consult the OP root") }) do
            yield
          end
        end
      end
    end
  end
end
