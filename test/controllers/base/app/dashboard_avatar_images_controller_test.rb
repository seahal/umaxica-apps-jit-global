# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::DashboardAvatarImagesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  # 1x1 PNG, distinct from the static default image.
  STORED_PNG = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  ).freeze
  DEFAULT_PNG_PATH = Rails.root.join("app/assets/images/base/default_avatar.png")

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @user = clients(:one)
    @user.update!(status_id: ClientStatus::ACTIVE)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(principal: @user, token: @token)
  end

  test "streams the selected Avatar's stored image privately with a revalidated ETag" do
    selected_avatar(@token).update!(image: png_io)
    @token.update!(last_used_at: 10.minutes.ago)
    last_used_at = @token.reload.last_used_at

    get base_app_dashboard_avatar_image_url(ri: "jp"), headers: session_headers(@user, @token)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal STORED_PNG.b, response.body.b
    assert_cache_control_private_revalidated
    assert_predicate response.headers["ETag"], :present?
    assert_match(/\Ainline/, response.headers["Content-Disposition"].to_s)
    assert_equal last_used_at, @token.reload.last_used_at
  end

  test "answers a matching If-None-Match with 304 and no body" do
    selected_avatar(@token).update!(image: png_io)
    get base_app_dashboard_avatar_image_url(ri: "jp"), headers: session_headers(@user, @token)
    etag = response.headers.fetch("ETag")

    get base_app_dashboard_avatar_image_url(ri: "jp"),
        headers: session_headers(@user, @token).merge("If-None-Match" => etag)

    assert_response :not_modified
    assert_empty response.body
    assert_cache_control_private_revalidated
  end

  test "HEAD returns the image headers without the body" do
    selected_avatar(@token).update!(image: png_io)

    head base_app_dashboard_avatar_image_url(ri: "jp"), headers: session_headers(@user, @token)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_empty response.body
  end

  test "serves the static default image when the required Avatar has no stored image" do
    assert_nil selected_avatar(@token).image

    get base_app_dashboard_avatar_image_url(ri: "jp"), headers: session_headers(@user, @token)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal File.binread(DEFAULT_PNG_PATH), response.body.b
    assert_cache_control_private_revalidated
  end

  test "an unauthenticated request receives no image" do
    selected_avatar(@token).update!(image: png_io)

    get base_app_dashboard_avatar_image_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    assert_not_equal STORED_PNG.b, response.body.b
  end

  test "request parameters never choose another principal's Avatar" do
    other = clients(:two)
    other.update!(status_id: ClientStatus::ACTIVE)
    other_token = ClientToken.create!(user: other, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(principal: other, token: other_token)
    other_avatar = selected_avatar(other_token)
    other_avatar.update!(image: png_io)

    get base_app_dashboard_avatar_image_url(
      ri: "jp", avatar_public_id: other_avatar.public_id,
      account_public_id: other_token.selected_account_public_id,
    ),
        headers: session_headers(@user, @token)

    assert_response :success
    assert_equal File.binread(DEFAULT_PNG_PATH), response.body.b
  end

  test "a session selection naming another principal's Avatar is refused, not defaulted" do
    other = clients(:two)
    other.update!(status_id: ClientStatus::ACTIVE)
    other_token = ClientToken.create!(user: other, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(principal: other, token: other_token)
    selected_avatar(other_token).update!(image: png_io)
    @token.update!(selected_avatar_public_id: other_token.selected_avatar_public_id)

    get base_app_dashboard_avatar_image_url(ri: "jp"), headers: session_headers(@user, @token)

    assert_response :not_found
    assert_not_equal STORED_PNG.b, response.body.b
  end

  test "a storage failure surfaces as an error instead of the default image" do
    avatar = selected_avatar(@token)
    avatar.update!(image: png_io)
    avatar.image.delete

    assert_raises(Shrine::FileNotFound, Errno::ENOENT, KeyError) do
      get base_app_dashboard_avatar_image_url(ri: "jp"), headers: session_headers(@user, @token)
    end
  end

  test "the image cache key changes with the Avatar, so another Persona's image is never reused" do
    other = clients(:two)
    other.update!(status_id: ClientStatus::ACTIVE)
    other_token = ClientToken.create!(user: other, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    select_token!(principal: other, token: other_token)
    mine = selected_avatar(@token)
    theirs = selected_avatar(other_token)
    mine.update!(image: png_io)
    theirs.update!(image: png_io)

    get base_app_dashboard_url(ri: "jp"), headers: session_headers(@user, @token)
    my_src = inertia_props.dig("sections", 0, "current_identity", "avatar_image", "src")
    get base_app_dashboard_url(ri: "jp"), headers: session_headers(other, other_token)
    their_src = inertia_props.dig("sections", 0, "current_identity", "avatar_image", "src")

    assert_equal base_app_dashboard_avatar_image_path(v: mine.image_cache_key), my_src
    assert_equal base_app_dashboard_avatar_image_path(v: theirs.image_cache_key), their_src
    assert_not_equal my_src, their_src

    get base_app_dashboard_avatar_image_url(ri: "jp"), headers: session_headers(@user, @token)
    my_etag = response.headers.fetch("ETag")
    get base_app_dashboard_avatar_image_url(ri: "jp"),
        headers: session_headers(other, other_token).merge("If-None-Match" => my_etag)

    assert_response :success
    assert_equal STORED_PNG.b, response.body.b
  end

  test "the dashboard points a stored-image-less Avatar at the default version" do
    get base_app_dashboard_url(ri: "jp"), headers: session_headers(@user, @token)

    assert_response :success
    assert_equal(
      { "src" => base_app_dashboard_avatar_image_path(v: "default") },
      inertia_props.dig("sections", 0, "current_identity", "avatar_image"),
    )
  end

  private

  def png_io
    io = StringIO.new(STORED_PNG.dup)
    io.define_singleton_method(:original_filename) { "avatar.png" }
    io
  end

  def assert_cache_control_private_revalidated
    cache_control = response.headers["Cache-Control"].to_s

    assert_includes cache_control, "private"
    assert_includes cache_control, "max-age=0"
    assert_includes cache_control, "must-revalidate"
    assert_not_includes cache_control, "public"
  end

  def select_token!(principal:, token:)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: principal)
    BaseSelectorAuthority.prepare(surface: :app, principal: principal, session: token)
  end

  def selected_avatar(token)
    Avatar.find_by!(public_id: token.reload.selected_avatar_public_id)
  end

  def session_headers(user, token)
    as_user_headers(user, host: @host, session_public_id: token.public_id)
  end
end
