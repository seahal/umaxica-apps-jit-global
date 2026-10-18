# typed: false
# frozen_string_literal: true

require "test_helper"

# A promotional email's call-to-action link comes from campaign input. Only an absolute HTTPS URL
# without credentials is rendered; anything else (another scheme, embedded credentials, control
# characters, a malformed URL) drops the button instead of shipping a hostile link.
class PromotionalMailerCtaUrlTest < ActionMailer::TestCase
  MAILERS = [Email::App::PromotionalMailer, Email::Org::PromotionalMailer, Email::Com::PromotionalMailer].freeze

  test "an https call-to-action is rendered with a lower-cased scheme and host on every surface" do
    MAILERS.each do |mailer|
      mail = mailer.with(
        title: "Campaign", body: "Hello", email_address: "to@example.com",
        cta_url: "  HTTPS://Example.COM/Offer?x=1  ",
      ).notice

      html = mail.html_part.body.to_s

      assert_includes html, 'href="https://example.com/Offer?x=1"', mailer.name
    end
  end

  test "unsafe call-to-action values are dropped instead of rendered" do
    unsafe = [
      "http://example.com/offer",
      "javascript:alert(1)",
      "https://user:pass@example.com/offer",
      "https:///no-host",
      "https://example.com/\u0000offer",
      "https://exa mple.com/",
      "",
      nil,
    ]

    MAILERS.each do |mailer|
      unsafe.each do |value|
        mail = mailer.with(title: "Campaign", body: "Hello", email_address: "to@example.com", cta_url: value).notice
        html = mail.html_part.body.to_s

        assert_not_includes html, I18n.t("mail.common.cta"), "#{mailer.name} rendered a CTA for #{value.inspect}"
        assert_no_match(/<a [^>]*href=/, html, "#{mailer.name} rendered a link for #{value.inspect}")
      end
    end
  end
end
