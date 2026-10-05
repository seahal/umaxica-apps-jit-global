# frozen_string_literal: true

require "test_helper"

class SecretPresentationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "one-time reveal retains escaped values, the native storage acknowledgement and both document form contracts" do
    html = Base::App::SecretPresentationsController.renderer.render(
      template: "base/app/secret_presentations/create", layout: false,
      assigns: { issuance: Struct.new(:origin, :planned_count).new("synthetic", 1),
                 values: ["synthetic<script>value</script>"], },
      locals: { confirmation_url: "/synthetic/confirm",
                cancel_url: "/synthetic/cancel",
                checkpoint_version: 7, },
    )
    document = Nokogiri::HTML(html)

    assert_equal "synthetic<script>value</script>", document.at_css("[data-secret-value] code").text
    assert_empty document.css("[data-secret-value] script")
    assert_equal 1, document.css("main h1").length
    confirmation = document.at_css("form[action='/synthetic/confirm']")

    assert_equal "post", confirmation["method"]
    assert_equal "false", confirmation["data-turbo"]
    assert_equal "patch", confirmation.at_css("input[name='_method']")["value"]
    assert_equal "7", confirmation.at_css("input[name='checkpoint_version']")["value"]
    assert_equal "0", confirmation.at_css("input[type='hidden'][name='stored']")["value"]
    stored = confirmation.at_css("input[type='checkbox'][name='stored']")

    assert_equal "1", stored["value"]
    assert_predicate stored["required"], :present?
    assert document.at_css("label[for='#{stored["id"]}']")
    cancellation = document.at_css("form[action='/synthetic/cancel']")

    assert_equal "post", cancellation["method"]
    assert_equal "delete", cancellation.at_css("input[name='_method']")["value"]
    assert_equal "false", cancellation["data-turbo"]
    assert document.at_css("script[src*='secret_presentation']")
  end
end
