# frozen_string_literal: true

require "test_helper"

# adr/passkey-identifier-first-sign-in.md V1: only an effective contact binding of the same surface
# selects an Identity; every other identifier selects nobody.
class PasskeySignInIdentityResolverQueryTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_email_statuses, :visitor_statuses, :visitor_email_statuses

  setup do
    @client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @email = @client.client_emails.create!(
      address: "resolver-#{SecureRandom.hex(6)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
  end

  test "an effective Email binding selects its Identity" do
    @email.finalize_binding!

    assert_equal @client.id, PasskeySignInIdentityResolverQuery.call(surface: :app, identifier: @email.address)&.id
  end

  test "an unfinalized or released binding selects nobody" do
    assert_nil PasskeySignInIdentityResolverQuery.call(surface: :app, identifier: @email.address)

    @email.finalize_binding!
    @email.release_binding!

    assert_nil PasskeySignInIdentityResolverQuery.call(surface: :app, identifier: @email.address)
  end

  [nil, "", " ", "not-an-identifier", "a\0b", "\xFF".dup.force_encoding("UTF-8"), 42].each do |identifier|
    test "a missing, empty or malformed identifier #{identifier.inspect} selects nobody" do
      assert_nil PasskeySignInIdentityResolverQuery.call(surface: :app, identifier: identifier)
    end
  end

  test "an unknown identifier selects nobody" do
    assert_nil PasskeySignInIdentityResolverQuery.call(
      surface: :app,
      identifier: "unknown-#{SecureRandom.hex(4)}@example.test",
    )
  end

  test "an APP contact never selects a COM Identity" do
    @email.finalize_binding!

    assert_nil PasskeySignInIdentityResolverQuery.call(surface: :com, identifier: @email.address)
  end

  test "an effective Telephone binding selects its Identity" do
    other = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    telephone = other.client_telephones.create!(
      number: "+8190#{format("%08d", SecureRandom.random_number(100_000_000))}",
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    telephone.finalize_binding!

    assert_equal other.id, PasskeySignInIdentityResolverQuery.call(surface: :app, identifier: telephone.number)&.id
  end

  test "an unsupported surface is a programming error" do
    assert_raises(KeyError) { PasskeySignInIdentityResolverQuery.call(surface: :org, identifier: "x") }
  end
end
