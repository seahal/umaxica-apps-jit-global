# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BannerPartialTest < ActionView::TestCase
  fixtures :client_banners, :visitor_banners, :clients, :client_statuses, :visitors, :visitor_statuses,
           :visitor_visibilities, :visitor_security_modes, :visitor_mfa_statuses

  test "renders title and body when title is present" do
    render partial: "layouts/shared/banner", locals: { banner: client_banners(:current_user_banner) }

    assert_includes rendered, "Client current banner"
    assert_includes rendered, "Client current banner body"
  end

  test "renders body without title heading when title is blank" do
    render partial: "layouts/shared/banner", locals: { banner: visitor_banners(:untitled_visitor_banner) }

    assert_includes rendered, "Visitor untitled banner body"
    assert_not_includes rendered, "<h2>"
  end
end
