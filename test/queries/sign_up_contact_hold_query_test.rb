# frozen_string_literal: true

require "test_helper"

# D-135: a contact held by an unfinished registration refuses a new sign-up until cleanup ran.
class SignUpContactHoldQueryTest < ActiveSupport::TestCase
  test "APP email held by an unfinished registration is held" do
    held = app_email("held-app@example.com", owner_status: ClientStatus::UNVERIFIED_WITH_SIGN_UP)

    assert SignUpContactHoldQuery.call(contact: candidate(ClientEmail.new(raw_address: held.address)))
  end

  test "APP email owned by a registered identity is not held" do
    [ClientStatus::ACTIVE, ClientStatus::VERIFIED_WITH_SIGN_UP].each_with_index do |status, index|
      owned = app_email("registered-app-#{index}@example.com", owner_status: status)

      assert_not SignUpContactHoldQuery.call(contact: candidate(ClientEmail.new(raw_address: owned.address)))
    end
  end

  test "APP email retired by cleanup is not held" do
    retired = app_email(
      "retired-app@example.com", owner_status: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
                                 contact_status: ClientEmailStatus::DELETED,
    )

    assert_not SignUpContactHoldQuery.call(contact: candidate(ClientEmail.new(raw_address: retired.address)))
  end

  test "APP email with another address is not held" do
    app_email("other-app@example.com", owner_status: ClientStatus::UNVERIFIED_WITH_SIGN_UP)

    assert_not SignUpContactHoldQuery.call(contact: candidate(ClientEmail.new(raw_address: "free-app@example.com")))
  end

  test "APP telephone held by an unfinished registration is held and a registered one is not" do
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    ClientTelephone.create!(
      user: owner, raw_number: "+12345670001", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    registered = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    ClientTelephone.create!(
      user: registered, raw_number: "+12345670002", confirm_policy: true, confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    assert SignUpContactHoldQuery.call(contact: candidate(ClientTelephone.new(raw_number: "+12345670001")))
    assert_not SignUpContactHoldQuery.call(contact: candidate(ClientTelephone.new(raw_number: "+12345670002")))
  end

  test "COM email and telephone follow the same predicate" do
    unfinished = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    VisitorEmail.create!(
      visitor: unfinished, raw_address: "held-com@example.com", confirm_policy: true,
      visitor_email_status_id: VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    VisitorTelephone.create!(
      visitor: unfinished, raw_number: "+12345670003", confirm_policy: true,
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    registered = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
    VisitorEmail.create!(
      visitor: registered, raw_address: "registered-com@example.com", confirm_policy: true,
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )

    assert SignUpContactHoldQuery.call(contact: candidate(VisitorEmail.new(raw_address: "held-com@example.com")))
    assert SignUpContactHoldQuery.call(contact: candidate(VisitorTelephone.new(raw_number: "+12345670003")))
    registered_candidate = candidate(VisitorEmail.new(raw_address: "registered-com@example.com"))

    assert_not SignUpContactHoldQuery.call(contact: registered_candidate)
  end

  test "a contact without a destination digest is refused as an argument error" do
    assert_raises(ArgumentError) { SignUpContactHoldQuery.call(contact: ClientEmail.new) }
  end

  private

  # The digest is derived on validation, as the sign-up controllers do before asking.
  def candidate(contact) = contact.tap(&:validate)

  def app_email(address, owner_status:, contact_status: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP)
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: owner_status)
    ClientEmail.create!(user: owner, raw_address: address, confirm_policy: true, user_email_status_id: contact_status)
  end
end
