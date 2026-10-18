# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class I18nRuntimeDefaultCleanupTest < ActiveSupport::TestCase
  LOCALES = %i(ja en).freeze

  # meta.default_title is intentionally absent: the brand and its TLD edition are
  # a locale-independent contract carried by the layouts' meta-tags site title, so
  # only page-specific titles are translated.
  KEYS = %w(
    defaults.never
    time.formats.short
    session_limit.edit.page_title
    sign.app.settings.totp.index.new_link
    sign.app.settings.withdrawal.recovery.link
    sign.app.settings.withdrawal.recovery.page_title
    sign.app.settings.withdrawal.recovery.deadline
    sign.app.settings.withdrawal.recovery.available
    sign.app.settings.withdrawal.recovery.submit
    sign.app.settings.withdrawal.recovery.confirm
    sign.app.settings.withdrawal.recovery.unavailable
    sign.app.verification.errors.no_passkey
    sign.org.in.back
    sign.org.in.session.restricted_notice
    sign.org.verification.errors.no_passkey
    sign.org.settings.google.show.disable
    sign.org.settings.sessions.revoke.others_button
    sign.org.settings.sessions.revoke.others_confirm
    help.app.contacts.new.submit
    help.app.contacts.new.cancel
    help.com.contacts.new.submit
    help.com.contacts.new.cancel
    help.org.contacts.new.submit
    help.org.contacts.new.cancel
    errors.invalid_authenticity_token
  ).freeze

  test "runtime default cleanup keys exist for ja and en" do
    LOCALES.each do |locale|
      KEYS.each do |key|
        assert I18n.exists?(key, locale), "missing #{key} for #{locale}"
      end
    end
  end
end
