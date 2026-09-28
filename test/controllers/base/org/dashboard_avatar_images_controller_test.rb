# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::DashboardAvatarImagesControllerTest < ActionDispatch::IntegrationTest
  STORED_PNG = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  ).freeze

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
  end

  test "no selected Avatar is a normal absence: no image element and a 404 image" do
    assert_nil @token.reload.selected_avatar_public_id

    get base_org_dashboard_url(ri: "jp"), headers: session_headers

    assert_response :success
    assert_not inertia_props.dig("sections", 0, "current_identity").key?("avatar_image")

    get base_org_dashboard_avatar_image_url(ri: "jp"), headers: session_headers

    assert_response :not_found
  end

  test "a selected Avatar without a stored image is a normal absence with no default image" do
    select_avatar!(provision_avatar!)

    get base_org_dashboard_url(ri: "jp"), headers: session_headers

    assert_response :success
    assert_not inertia_props.dig("sections", 0, "current_identity").key?("avatar_image")

    get base_org_dashboard_avatar_image_url(ri: "jp"), headers: session_headers

    assert_response :not_found
    assert_empty response.body
  end

  test "a selected Avatar with a stored image is shown and streamed privately" do
    avatar = provision_avatar!
    avatar.update!(image: png_io)
    select_avatar!(avatar)

    get base_org_dashboard_url(ri: "jp"), headers: session_headers

    assert_equal(
      { "src" => base_org_dashboard_avatar_image_path(v: avatar.image_cache_key) },
      inertia_props.dig("sections", 0, "current_identity", "avatar_image"),
    )

    get base_org_dashboard_avatar_image_url(ri: "jp"), headers: session_headers

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal STORED_PNG.b, response.body.b
    assert_includes response.headers["Cache-Control"].to_s, "private"
    assert_includes response.headers["Cache-Control"].to_s, "must-revalidate"
  end

  test "switching back to the Avatar-less selection drops the previous Avatar's image" do
    avatar = provision_avatar!
    avatar.update!(image: png_io)
    select_avatar!(avatar)
    get base_org_dashboard_avatar_image_url(ri: "jp"), headers: session_headers
    etag = response.headers.fetch("ETag")

    avatarless = switcher.current.fetch(:candidates).find { |candidate| candidate[:avatar].nil? }
    switcher.switch(
      account_public_id: avatarless.fetch(:public_id),
      organization_public_id: avatarless.dig(:organization, :public_id),
      organization_unit_public_id: avatarless.dig(:organization, :unit_public_id),
    )

    assert_nil @token.reload.selected_avatar_public_id

    get base_org_dashboard_url(ri: "jp"), headers: session_headers

    assert_not inertia_props.dig("sections", 0, "current_identity").key?("avatar_image")

    get base_org_dashboard_avatar_image_url(ri: "jp"), headers: session_headers.merge("If-None-Match" => etag)

    assert_response :not_found
  end

  test "an unauthenticated request receives no image" do
    avatar = provision_avatar!
    avatar.update!(image: png_io)
    select_avatar!(avatar)

    get base_org_dashboard_avatar_image_url(ri: "jp"), headers: host_headers(@host)

    assert_not_equal 200, response.status
    assert_not_equal STORED_PNG.b, response.body.b
  end

  test "com exposes no Avatar image route" do
    assert_not Rails.application.routes.named_routes.key?(:base_com_dashboard_avatar_image)
  end

  private

  def provision_avatar!
    AvatarProvisioning::Create.call(
      actor: @operator,
      subject_type: :agent,
      subject: @bootstrap.account,
      avatar_params: { moniker: "Org Avatar" },
      handle_params: { handle: "org-#{SecureRandom.hex(5)}" },
      owner_surface: "org",
      owner_collective_public_id: @bootstrap.collective.public_id,
    ).avatar
  end

  def select_avatar!(avatar)
    candidate =
      BaseSelectorAuthority.new(surface: :org, principal: @operator, session: @token)
        .selectable_candidates.find { |entry| entry.dig(:public, :avatar_public_id) == avatar.public_id }
    BaseSelectorAuthority.select(
      surface: :org, principal: @operator, session: @token,
      params: candidate.fetch(:public),
    )
  end

  def switcher
    BaseSwitcherAuthority.new(surface: :org, principal: @operator, session: @token.reload)
  end

  def png_io
    io = StringIO.new(STORED_PNG.dup)
    io.define_singleton_method(:original_filename) { "avatar.png" }
    io
  end

  def session_headers
    as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
  end
end
