# frozen_string_literal: true

require "test_helper"

class PresentationLabelsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "view-owned navigation names are translated without changing Inertia props" do
    I18n.with_locale(:ja) do
      html = ApplicationController.renderer.render(partial: "shared/ui/presentation_labels")
      document = Nokogiri::HTML.fragment(html)

      assert_equal "フッターナビゲーション", document.at_css('meta[name="ui-footer"]')["content"]
      assert_equal "ページ送り", document.at_css('meta[name="ui-pagination"]')["content"]
      assert_equal "お知らせ", document.at_css('meta[name="ui-information"]')["content"]
      assert_empty document.css("script")
    end
    I18n.with_locale(:en) do
      html = ApplicationController.renderer.render(partial: "shared/ui/presentation_labels")

      assert_equal "Footer navigation", Nokogiri::HTML.fragment(html).at_css('meta[name="ui-footer"]')["content"]
    end
  end
end
