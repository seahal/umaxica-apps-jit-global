# typed: false
# frozen_string_literal: true

require "test_helper"

class LayoutMetaTagsTest < ActiveSupport::TestCase
  LAYOUT_PATHS = {
    "Base::App" => "app/views/layouts/base/app/application.html.erb",
    "Base::Com" => "app/views/layouts/base/com/application.html.erb",
    "Base::Org" => "app/views/layouts/base/org/application.html.erb",
    "Auth::App" => "app/views/layouts/auth/app/application.html.erb",
    "Auth::Org" => "app/views/layouts/auth/org/application.html.erb",
  }.freeze

  INERTIA_LAYOUT_PATHS = {
    "Base::App::Inertia" => "app/views/layouts/base/app/inertia.html.erb",
  }.freeze

  test "all layouts include a charset meta tag" do
    LAYOUT_PATHS.merge(INERTIA_LAYOUT_PATHS).each do |name, path|
      content = Rails.root.join(path).read

      assert_includes content, '<meta charset="utf-8">', "Expected charset meta tag in #{name} layout (#{path})"
    end
  end

  # Turbo layouts only: an Inertia shell never loads Turbo (see StylesheetTagsTest).
  test "all layouts include turbo-refresh-scroll meta tag" do
    LAYOUT_PATHS.each do |name, path|
      content = Rails.root.join(path).read

      assert_match(
        /turbo-refresh-scroll/, content,
        "Expected turbo-refresh-scroll meta tag in #{name} layout (#{path})",
      )
    end
  end

  test "all layouts include title tag" do
    LAYOUT_PATHS.merge(INERTIA_LAYOUT_PATHS).each do |name, path|
      content = Rails.root.join(path).read

      assert_match(
        /display_meta_tags|<title>/, content,
        "Expected title tag in #{name} layout (#{path})",
      )
    end
  end

  test "inertia layout includes lang and theme markers" do
    content = Rails.root.join("app/views/layouts/base/app/inertia.html.erb").read

    assert_includes content, 'lang="<%= get_language %>"'
    assert_includes content, 'data-theme="<%= theme_cookie_value %>"'
    assert_includes content, 'class="<%= theme_html_class %>"'
    assert_includes content, "page_title(inertia_page&.dig(:props, :title))"
  end
end
