# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BannerPartialTest < ActionView::TestCase
  fixtures :client_banners, :clients, :client_statuses

  test "renders title and body when title is present" do
    render partial: "layouts/shared/banner", locals: { banner: client_banners(:current_user_banner) }

    assert_includes rendered, "Client current banner"
    assert_includes rendered, "Client current banner body"
  end

  test "renders body without title heading when title is blank" do
    # Plain value object standing in for a banner record with a blank title;
    # no retained banner fixture has an untitled title, and the partial only
    # reads `title` and `body`.
    untitled_banner = Struct.new(:title, :body).new("", "Untitled banner body")

    render partial: "layouts/shared/banner", locals: { banner: untitled_banner }

    assert_includes rendered, "Untitled banner body"
    assert_not_includes rendered, "<h2>"
  end
end
