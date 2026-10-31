# typed: false
# frozen_string_literal: true

require "test_helper"

# D-57 (two.md section 4.7): the browser binding makes stored consent readable only for the browser
# that granted it. The write path stores the SHA-256 digest of a 32-byte CSPRNG value; the raw
# value stays in the cookie. Reads are constant-time and never mint or extend.
class PreferenceBrowserBindingTest < ActiveSupport::TestCase
  fixtures :com_preferences, :com_preference_statuses

  test "mint_value is a 43-character URL-safe random string" do
    value = PreferenceBrowserBinding.mint_value

    assert_equal 43, value.length
    assert_match(/\A[A-Za-z0-9_-]{43}\z/, value)
    assert_not_equal PreferenceBrowserBinding.mint_value, value
  end

  test "digest_for matches and rejects in constant time semantics" do
    raw = PreferenceBrowserBinding.mint_value
    digest = PreferenceBrowserBinding.digest_for(raw)

    assert_equal 64, digest.length
    assert_predicate PreferenceBrowserBinding.matches?(raw, digest), :present?
    assert_not PreferenceBrowserBinding.matches?("#{raw}x", digest)
    assert_not PreferenceBrowserBinding.matches?(raw, nil)
    assert_not PreferenceBrowserBinding.matches?(nil, digest)
    assert_not PreferenceBrowserBinding.matches?("short", digest)
  end

  test "the digest column accepts only a 64-hex digest" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    record = ComPreferenceBrowserBinding.new(preference: preference, digest: "z" * 64)

    assert_not record.valid?
    assert record.errors.of_kind?(:digest, :invalid)

    record.digest = PreferenceBrowserBinding.digest_for(PreferenceBrowserBinding.mint_value)

    assert_predicate record, :valid?
    assert_not record.errors.of_kind?(:digest, :invalid)
  end

  test "com cookie names use their required secure prefixes in each environment" do
    JitSessionCookieConfig.stub(:force_secure?, true) do
      assert_equal "__Host-preference_binding", PreferenceCookieName.binding
      assert_equal "__Secure-preference", PreferenceCookieName.anonymous_jwt
      assert_equal "__Secure-experience", PreferenceCookieName.anonymous_experience
    end
    JitSessionCookieConfig.stub(:force_secure?, false) do
      assert_equal "__Host-preference_binding", PreferenceCookieName.binding
      assert_equal "__Secure-preference", PreferenceCookieName.anonymous_jwt
      assert_equal "__Secure-experience", PreferenceCookieName.anonymous_experience
    end
  end
end
