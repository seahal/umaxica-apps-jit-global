# typed: false
# frozen_string_literal: true

require "test_helper"

# D-153 / D-160 (4): every first-party RP serves one generic interruption page.
class RpSignInterruptionTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  HOSTS = %w(
    www.umaxica.app www.umaxica.com www.umaxica.org jp.umaxica.app jp.umaxica.com jp.umaxica.org
    www-jp.umaxica.app www-jp.umaxica.com www-jp.umaxica.org palm-jp.umaxica.app tech.umaxica.org edit.umaxica.org
  ).freeze

  test "the interruption page answers 200 no-store with the fixed text on every RP" do
    HOSTS.each do |host|
      host!(host)
      https!

      [{}, { reason: "access_denied", ri: "jp" }].each do |params|
        get "/sign/interruption", params: params

        assert_equal [200, nil], [response.status, response.headers["Location"]], host
        assert_includes response.headers["Cache-Control"], "no-store", host
        assert_includes response.body, I18n.t("oidc_rp.interruption.body"), host
        assert_not_includes response.body, "access_denied", host
      end
    end
  end

  test "the interruption copy is the owner's text in both languages" do
    assert_equal "ログインできませんでした。再度ログインしてください。", I18n.t("oidc_rp.interruption.body", locale: :ja)
    assert_equal "Sign-in could not be completed. Please sign in again.",
                 I18n.t("oidc_rp.interruption.body", locale: :en)
  end
end
